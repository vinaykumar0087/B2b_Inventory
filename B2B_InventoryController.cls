/**
* @description       : It create Lead or case based in user type  
* @author           : vinay
* @group             :
* @last modified on  : 19.Dec.2022
* @last modified by  : vinay
**/
public without sharing class B2B_InventoryController {

    @AuraEnabled
    public static Map<String,Object> getInventoryData(Map<String,Object> dataMap){
        Map<String,Object> resultMap = new Map<String,Object>();
        try {
            if (dataMap != null && dataMap.containsKey(B2B_SetupConstants.PRODUCTID) && dataMap.get(B2B_SetupConstants.PRODUCTID) != null) {

                String productId = (String)dataMap.get(B2B_SetupConstants.PRODUCTID);
                system.debug('productId.........'+ productId);
                Inventory__c inventoryObj = [SELECT Product__c,Product__r.StockKeepingUnit FROM Inventory__c WHERE Product__c = :productId];
                string productsku = inventoryObj.Product__r.StockKeepingUnit;
                system.debug('productsku>>>>>>>' + productsku);
                string orgUrl = Url.getOrgDomainUrl().toExternalForm();
                string endpoint = orgUrl + B2B_SetupConstants.HTTP_SERVICE_APEX_REST + '/v1/Inventorysrc/' + productsku;
                
                Http http = new Http();
                HttpRequest request = new HttpRequest();
                request.setEndpoint(endpoint);
                request.setHeader(B2B_SetupConstants.HTTP_AUTHORIZATION_HEADER, 'Bearer ' + UserInfo.getSessionId());
                request.setMethod(B2B_SetupConstants.HTTP_REQUEST_GET);

                HttpResponse response = http.send(request);
                system.debug(response);
                system.debug(JSON.deserializeUntyped(response.getBody()));
                 resultMap = (Map<String,Object>)JSON.deserializeUntyped(response.getBody());

                Integer statusCode = response.getStatusCode();
                system.debug('statusCode>>>>' + statusCode);
                if(statusCode  == 200){
                    system.debug('is cuscces called');
                    resultMap.put(B2B_SetupConstants.IS_REQUEST_SUCCESS,true);
                }
                system.debug('res>>>>>>>>' + resultMap);

            }
        } catch (Exception e) {
            system.debug(e.getMessage());
            resultMap.put(B2B_SetupConstants.IS_REQUEST_SUCCESS,false);
            resultMap.put('Message',e.getMessage());
        }
        return resultMap;
    }

    @AuraEnabled
    public static Map<String,Object> updateInventoryFields(Map<String,Object> dataMap){
        String productId = '';
        Inventory__c inventoryObj = new Inventory__c();
        cartItem cartItemObj = new cartItem();
        Map<String,Object> resultMap = new Map<String,Object>();
        string productsku = '';
        Decimal passedQuantity = 0;
        string ctItemId = '';

        try{
            if (dataMap != null && dataMap.containsKey(B2B_SetupConstants.PRODUCTID)) {
                string cartRecordId = (String)dataMap.get(B2B_SetupConstants.CART_ID);
                string condition = (String)dataMap.get('condition');

                if( dataMap.get(B2B_SetupConstants.PRODUCTID) != null){ 
                    productId = (String)dataMap.get(B2B_SetupConstants.PRODUCTID);
                    inventoryObj = [SELECT Product__c,Product__r.StockKeepingUnit FROM Inventory__c WHERE Product__c = :productId];
                    productsku = inventoryObj.Product__r.StockKeepingUnit;
                    passedQuantity = (Decimal)dataMap.get(B2B_SetupConstants.QUANTITY);
                }
                if(dataMap.get('cartItemId') != null && condition == 'removeSingleproduct'){ 
                    ctItemId = (String)dataMap.get('cartItemId');
                    cartItemObj = [SELECT Id,Product2Id, Quantity, Sku  from CartItem Where Id = : ctItemId] ;
                    productsku = cartItemObj.Sku;
                    passedQuantity = cartItemObj.Quantity;
                }
                else if(dataMap.get('cartItemId') != null && condition == 'quantityincreased'){
                    ctItemId = (String)dataMap.get('cartItemId');
                    cartItemObj = [SELECT Id,Product2Id, Quantity, Sku  from CartItem Where Id = : ctItemId] ;
                    productsku = cartItemObj.Sku;
                    passedQuantity = (Decimal)dataMap.get(B2B_SetupConstants.QUANTITY);
                }
                else if(dataMap.get('cartItemId') != null && condition == 'quantitydecreased'){
                    ctItemId = (String)dataMap.get('cartItemId');
                    cartItemObj = [SELECT Id,Product2Id, Quantity, Sku  from CartItem Where Id = : ctItemId] ;
                    productsku = cartItemObj.Sku;
                    passedQuantity = (Decimal)dataMap.get(B2B_SetupConstants.QUANTITY);
                }
                
                string orgUrl = Url.getOrgDomainUrl().toExternalForm();
                string endpoint = orgUrl + B2B_SetupConstants.HTTP_SERVICE_APEX_REST + '/v1/Inventorysrc/';

                Map<String,Object> mapRequestBody = new Map<String, Object>();
                B2B_InventoryRestService.Request  b2breq = new B2B_InventoryRestService.Request();
                b2breq.sku = productsku;
                b2breq.quantity = passedQuantity;
                b2breq.cartId = cartRecordId;
                b2breq.checkCondition = condition;
                b2breq.cartItemId = ctItemId;
                mapRequestBody.put('request' ,b2breq);
                system.debug(JSON.serialize(mapRequestBody));

                Http http = new Http();
                HttpRequest request = new HttpRequest();
                request.setEndpoint(endpoint);
                request.setHeader(B2B_SetupConstants.HTTP_AUTHORIZATION_HEADER, 'Bearer ' + UserInfo.getSessionId());
                request.setHeader(B2B_SetupConstants.HTTP_CONTENT_TYPE, B2B_SetupConstants.HTTP_CONTENT_APP_JSON);
              
                request.setBody(JSON.serialize(mapRequestBody));
                request.setMethod(B2B_SetupConstants.HTTP_REQUEST_PATCH);

                HttpResponse response = http.send(request);
                Integer statusCode = response.getStatusCode();
                if(statusCode  == 200){
                    resultMap.put(B2B_SetupConstants.IS_REQUEST_SUCCESS,true);
                }
            }
            return resultMap;    
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    @AuraEnabled
    public static Map<String,Object> createCases(){
        Map<String,Object> respMap = new Map<String,Object>();
        try {
            String userId = UserInfo.getUserId();
            User userObj = [SELECT ContactId, AccountId FROM User WHERE Id = :userId LIMIT 1];

            Case createCase = new Case();
            createCase.AccountId = userObj.AccountId;
            createCase.ContactId = userObj.ContactId;
            createCase.Status = 'New';
            createCase.Origin = 'Web';
            createCase.Description = 'Please Notify when it is available in our stock';
            insert createCase;
            respMap.put(B2B_SetupConstants.CASE_OBJ, createCase);
            return respMap;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}