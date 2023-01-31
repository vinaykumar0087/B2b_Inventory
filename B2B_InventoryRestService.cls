/**
* @description       : It create Lead or case based in user type  
* @author            : Vinay
* @group             :
* @last modified on  : 13.Dec.2022
* @last modified by  : Vinay
**/
@RestResource(UrlMapping='/v1/Inventorysrc/*')
global without sharing class B2B_InventoryRestService {

    @HttpGet
    global static Inventory__c getRecord() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String productsku = req.requestURI.substring(req.requestURI.lastIndexOf('/')+1);
       Inventory__c result = [SELECT Product__c, Status__c, Available_For_Purchase__c,
                        Qty_Available__c FROM Inventory__c WHERE Product__r.StockKeepingUnit = :productsku];
        return result;
    }

    @HttpPatch
    global static void updatereserveInventoryField(Request request){
        RestRequest req = RestContext.request;
        WebCart cartData = new WebCart();
        Inventory__c result  = new Inventory__c();
        try{
            if(request != null && request.sku != null && request.quantity != null){
                string sku = request.sku ;
                Decimal quantity = request.quantity;
                string cartId = request.cartId;
                string checkcondition = request.checkcondition;
                string cartItemId = request.cartItemId;
                if(cartId != null){
                    cartData = [SELECT Id, Status FROM WebCart WHERE Id = :cartId ];
                }

                if(cartData.Status == 'Closed'){
                    system.debug('cart status was closed ') ;// add condition to check same product 
                    updatecommitedquantity(cartId);
                }
                else if(checkcondition == 'removeSingleproduct'){
                    rollbackSingleItemReservedQty(quantity,sku);
                }
                else if(checkcondition == 'clearproductinCart'){
                    rollbackReservedQty(cartId);
                }
                else if(checkcondition == 'quantityincreased'){
                    updateReservedQuantity(quantity,sku,'quantityincreased');
                }
                else if(checkcondition == 'quantitydecreased'){
                    decreasedReservedQty(quantity,sku);
                }
                else{
                    updateReservedQuantity(quantity,sku,null);
                }
            }
        }
        catch(Exception e){
            system.debug('e.getMessage+   '+ e);
            throw new AuraHandledException(e.getMessage());
        }
    }

    public static void updatecommitedquantity(String cartId){
        List<Inventory__c> inventoryListToUpdate = new List<Inventory__c>();
        if(cartId != null){
            system.debug('data was retrived');
            List<CartItem> cartItemsList = [SELECT Id, Product2Id, Quantity, CartId FROM CartItem WHERE CartId = :cartId];
            system.debug('cartItemsList>>>>>>' + cartItemsList);

            Map<String, Decimal> cartItemMap = new Map<String, Decimal> ();

            for(CartItem eachItem : cartItemsList){
                system.debug('ciList>>>>>>>' + cartItemsList);
                cartItemMap.put(eachItem.Product2Id,eachItem.Quantity);
            }
            set<String> productIdSet =  cartItemMap.keySet();
           

            for(Inventory__c eachInventory : [SELECT Product__c, Status__c, Committed__c, Reserved__c, Available_For_Purchase__c
                                                    FROM Inventory__c WHERE Product__c in :productIdSet]) {
                if(eachInventory.Committed__c == null){
                    system.debug('checked is null');
                    eachInventory.Committed__c = cartItemMap.get(eachInventory.Product__c);
                    eachInventory.Reserved__c= eachInventory.Reserved__c-cartItemMap.get(eachInventory.Product__c);
                }
                else{
                    system.debug('checked isnot null');
                    eachInventory.Committed__c = eachInventory.Committed__c+cartItemMap.get(eachInventory.Product__c);
                    eachInventory.Reserved__c = eachInventory.Reserved__c-cartItemMap.get(eachInventory.Product__c);
                }
                if(eachInventory.Available_For_Purchase__c == eachInventory.Committed__c+eachInventory.Reserved__c){
                    eachInventory.Status__c = 'Out Of Stock';
                }

                inventoryListToUpdate.add(eachInventory);
            }

            if (inventoryListToUpdate.size() > 0){
                update inventoryListToUpdate;
            }  
        }
    }
    public static void rollbackReservedQty(String cartId){
        List<Inventory__c> inventoryListToUpdate = new List<Inventory__c>();
        if(cartId != null){
            system.debug('data was retrived');
            List<CartItem> cartItemsList = [SELECT Id, Product2Id, Quantity, CartId FROM CartItem WHERE CartId = :cartId];
            system.debug('cartItemsList>>>>>>' + cartItemsList);

            Map<String, Decimal> cartItemMap = new Map<String, Decimal> ();

            for(CartItem eachItem : cartItemsList){
                system.debug('ciList>>>>>>>' + cartItemsList);
                cartItemMap.put(eachItem.Product2Id,eachItem.Quantity);
            }
            set<String> productIdSet =  cartItemMap.keySet();
           

            for(Inventory__c eachInventory : [ SELECT Product__c, Status__c, Committed__c, Reserved__c, Available_For_Purchase__c
            FROM Inventory__c WHERE Product__c in :productIdSet]) {
                eachInventory.Reserved__c = eachInventory.Reserved__c-cartItemMap.get(eachInventory.Product__c);
                if(eachInventory.Available_For_Purchase__c != 0){
                    eachInventory.Status__c = 'In Stock';
                }

                inventoryListToUpdate.add(eachInventory);
            }

            if (inventoryListToUpdate.size() > 0){
                update inventoryListToUpdate;
            }  
        }
    }

    public static void updateReservedQuantity(Decimal productQuantity, string productSku, string cCondition){
        Inventory__c inventoryObj = [SELECT Product__c, Status__c, Availability_Message__c, Available_For_Purchase__c, Qty_Available__c, Reserved__c, Committed__c 
                                    FROM Inventory__c WHERE Product__r.StockKeepingUnit = :productSku
                                ];
        if(inventoryObj != null){
            if( inventoryObj.Reserved__c == null){
                inventoryObj.Reserved__c = productQuantity;
            }
            else{
                inventoryObj.Reserved__c = inventoryObj.Reserved__c+productQuantity;
            }
            if(inventoryObj.Available_For_Purchase__c == inventoryObj.Reserved__c && cCondition != 'quantityincreased'){
                inventoryObj.Status__c = 'Out Of Stock';
            }
            update inventoryObj;
        }
    }
    public static void decreasedReservedQty(Decimal productQuantity, string productSku){
        Inventory__c inventoryObj = [SELECT Product__c, Status__c, 	Availability_Message__c, Available_For_Purchase__c, Qty_Available__c, Reserved__c, Committed__c 
                                    FROM Inventory__c WHERE Product__r.StockKeepingUnit = :productSku];
        
                inventoryObj.Reserved__c = inventoryObj.Reserved__c-productQuantity;
            
            if(inventoryObj.Available_For_Purchase__c > productQuantity){
                inventoryObj.Status__c = 'In Stock';
            }
            update inventoryObj;
    }

    public static void rollbackSingleItemReservedQty(Decimal productQuantity, string productSku){
        Inventory__c inventoryObj = [SELECT Product__c, Status__c, Availability_Message__c, Available_For_Purchase__c, Qty_Available__c, Reserved__c, Committed__c 
                                    FROM Inventory__c WHERE Product__r.StockKeepingUnit = :productSku
                                ];
        if(inventoryObj != null){
            if( inventoryObj.Reserved__c == null){
                inventoryObj.Reserved__c = productQuantity;
            }
            else{
                inventoryObj.Reserved__c = inventoryObj.Reserved__c-productQuantity;
            }
            if(inventoryObj.Available_For_Purchase__c != 0 ){
                inventoryObj.Status__c = 'In Stock';
            }
            update inventoryObj;
        }
    }
    
    global class Request
    {
        global string sku;
        global Decimal quantity;
        global string cartId;
        global string checkcondition;
        global string cartItemId;
   }
}