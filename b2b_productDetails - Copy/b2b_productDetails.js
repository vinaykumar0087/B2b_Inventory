import { LightningElement, wire,api } from 'lwc';

import communityId from '@salesforce/community/Id';
import getProduct from '@salesforce/apex/B2BGetInfo.getProduct';
import getCartSummary from '@salesforce/apex/B2BGetInfo.getCartSummary';
import addToCart from '@salesforce/apex/B2BGetInfo.addToCart';
import createAndAddToList from '@salesforce/apex/B2BGetInfo.createAndAddToList';
import getProductPrice from '@salesforce/apex/B2BGetInfo.getProductPrice';
import getInventoryData from '@salesforce/apex/B2B_InventoryController.getInventoryData';
//import getProductSku from '@salesforce/apex/B2B_InventoryController.getProductSku';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { resolve } from 'c/cmsResourceResolver';

export default class B2b_productDetails extends LightningElement {
    _effectiveAccountId;
    hasProductInStock = true;
    totalProducts;
    showProductCount;


    @api
    get effectiveAccountId() {
        return this._effectiveAccountId;
    }

    /**
     * Sets the effective account - if any - of the user viewing the product
     * and fetches updated cart information
     */
     set effectiveAccountId(newId) {
        this._effectiveAccountId = newId;
        this.updateCartInformation();
    }

    @api recordId; //product id

    @api customDisplayFields;
    cartSummary;

    //get product data
    @wire(getProduct, {
        communityId: communityId,
        productId: '$recordId',
        effectiveAccountId: '$resolvedEffectiveAccountId'
    })
    product;

  

    //get product Price
    @wire(getProductPrice, {
        communityId: communityId,
        productId: '$recordId',
        effectiveAccountId: '$resolvedEffectiveAccountId'
    })
    productPrice;


    // get normalized effective account
    get resolvedEffectiveAccountId() {
        const effectiveAccountId = this.effectiveAccountId || '';
        let resolved = null;

        if (
            effectiveAccountId.length > 0 &&
            effectiveAccountId !== '000000000000000'
        ) {
            resolved = effectiveAccountId;
        }
        return resolved;
    }

    get hasProduct() {
        //checking we have product data or not 
        return this.product.data !== undefined;
    }


    //get all the info to send child comp to display the UI 

    get displayableProduct() {
        return {
            categoryPath: this.product.data.primaryProductCategoryPath.path.map(
                (category) => ({
                    id: category.id,
                    name: category.name
                })
            ),
            description: this.product.data.fields.Description,
            image: {
                alternativeText: this.product.data.defaultImage.alternativeText,
                url: resolve(this.product.data.defaultImage.url)
            },
           // inStock: this.inStock.data === true,
            name: this.product.data.fields.Name,
            price: {
                currency: ((this.productPrice || {}).data || {})
                    .currencyIsoCode,
                negotiated: ((this.productPrice || {}).data || {}).unitPrice
            },
            sku: this.product.data.fields.StockKeepingUnit,
            customFields: Object.entries(
                this.product.data.fields || Object.create(null)
            )
                .filter(([key]) =>
                    (this.customDisplayFields || '').includes(key)
                )
                .map(([key, value]) => ({ name: key, value }))
        };
    }


    /**
     * Gets whether the cart is currently locked
     *
     * Returns true if the cart status is set to either processing or checkout (the two locked states)
     */

     get _isCartLocked() {
        const cartStatus = (this.cartSummary || {}).status;
        return cartStatus === 'Processing' || cartStatus === 'Checkout';
    }

    //Handle the add to cart 

    addToCart(event) {
        addToCart({
            communityId: communityId,
            productId: this.recordId,
            quantity: event.detail.quantity,
            effectiveAccountId: this.resolvedEffectiveAccountId
        })
            .then(() => {
                //fire custom event 
                this.dispatchEvent(
                    new CustomEvent('cartchanged', {
                        bubbles: true,
                        composed: true
                    })
                );
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Your cart has been updated.',
                        variant: 'success',
                        mode: 'dismissable'
                    })
                );
            })
            .catch(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message:
                            '{0} could not be added to your cart at this time. Please try again later.',
                        messageData: [this.displayableProduct.name],
                        variant: 'error',
                        mode: 'dismissable'
                    })
                );
            });
    }

     //Handles a user request to add the product to a newly created wishlist.

    createAndAddToList() {
        let listname = this.product.data.primaryProductCategoryPath.path[0]
            .name;
        createAndAddToList({
            communityId: communityId,
            productId: this.recordId,
            wishlistName: listname,
            effectiveAccountId: this.resolvedEffectiveAccountId
        })
            .then(() => {
                this.dispatchEvent(new CustomEvent('createandaddtolist'));
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: '{0} was added to a new list called "{1}"',
                        messageData: [this.displayableProduct.name, listname],
                        variant: 'success',
                        mode: 'dismissable'
                    })
                );
            })
            .catch(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message:
                            '{0} could not be added to a new list. Please make sure you have fewer than 10 lists or try again later',
                        messageData: [this.displayableProduct.name],
                        variant: 'error',
                        mode: 'dismissable'
                    })
                );
            });
    }

    /**
     * Ensures cart information is up to date
     */
    updateCartInformation() {
        getCartSummary({
            communityId: communityId,
            effectiveAccountId: this.resolvedEffectiveAccountId
        })
            .then((result) => {
                this.cartSummary = result;
            })
            .catch((e) => {
                // Handle cart summary error properly
                // For this sample, we can just log the error
                console.log(e);
            });
    }
    handleproductSKu(){
        getProductSku({ProductId : this.recordId})
        .then((result) => {
            console.log('exc')
            console.log(result)  
        }).catch((e) => {
            console.log(e);
        })  
    }
    handleGetInventoryData(){
        console.log('called')
        let mapReqParams = {
            'ProductId' : this.recordId,
            //'productSku' :this.product.data.fields.StockKeepingUnit
        };

        getInventoryData({dataMap : mapReqParams})
        .then((result) => {
            console.log('getinvdata')
            console.log(result)
            if(result.isRequestSuccess == true  && result.Available_For_Purchase__c == 0 && result.Status__c == "Out Of Stock"){
                console.log('out of stock');
                this.hasProductInStock = false;
                console.log('out of stock>>>>>' + this.hasProductInStock)
            }
            else if(result.isRequestSuccess == false){
                console.log('handle error');
                this.hasProductInStock = false;
                console.log('handle error>>>>>' + this.hasProductInStock)
            }
            this.totalProducts =  result.Available_For_Purchase__c;
            this.showProductCount = result.Available_For_Purchase__c-1;
            
        }).catch((e) => {
            if(result.isRequestSuccess == false){
                console.log('handle error');
                this.handleproductSKu = false;
                console.log('handle error>>>>>' + this.hasProductInStock)
            }
            console.log(e);
        })
    }

    connectedCallback() {
    //     console.log('connected callback')
    //     this.handleproductSKu();
    //     console.log(this.recordId);
        this.handleGetInventoryData();
        console.log(this.hasProductInStock);
        this.updateCartInformation();
       
    }

}