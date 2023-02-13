import { LightningElement,api,wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';


import updateInventoryFields from '@salesforce/apex/B2B_InventoryController.updateInventoryFields';
import CreateCases from '@salesforce/apex/B2B_InventoryController.createCases';



// A fixed entry for the home page.
const homePage = {
    name: 'Home',
    type: 'standard__namedPage',
    attributes: {
        pageName: 'home'
    }
};

export default class B2b_productDetailsDisplay extends NavigationMixin(LightningElement) {

    
    /**
     * Gets or sets which custom fields should be displayed (if supplied).
     *
     * @type {CustomField[]}
     */
    @api
    customFields;

    /**
     * Gets or sets whether the cart is locked
     *
     * @type {boolean}
     */
    @api
    cartLocked;


    @api recordId;

    @api quantity;

    /**
     * Gets or sets the name of the product.
     *
     * @type {string}
     */
    @api
    description;

    /**
     * Gets or sets the product image.
     *
     * @type {Image}
     */
    @api
    image;

    /**
     * Gets or sets whether the product is "in stock."
     *
     * @type {boolean}
     */
    @api
    inStock

    /**
     * Gets or sets the name of the product.
     *
     * @type {string}
     */
    @api
    name;

    /**
     * Gets or sets the price - if known - of the product.
     * If this property is specified as undefined, the price is shown as being unavailable.
     *
     * @type {Price}
     */
    @api
    price;

    /**
     * Gets or sets teh stock keeping unit (or SKU) of the product.
     *
     * @type {string}
     */
    @api
    sku;

    @api
    showcount;

    _invalidQuantity = false;
    _quantityFieldValue = 1;
    _categoryPath;
    _resolvedCategoryPath = [];
    showerror = false;
    showSpinner = false;
    title = 'Hero Cycles';
    message = 'Thanks for choosing Hero Cycles Product';
    variant = 'success';
    showSpinner = false;

    // A bit of coordination logic so that we can resolve product URLs after the component is connected to the DOM,
    // which the NavigationMixin implicitly requires to function properly.
    _resolveConnected;
    _connected = new Promise((resolve) => {
        this._resolveConnected = resolve;
    });

    connectedCallback() {
        console.log('................' + this.recordId);
        console.log('stock>>' + this.inStock);
        console.log(this._quantityFieldValue);
        console.log(this.quantity);
        this._resolveConnected();

        //this.handleupadteFields();
    }

    disconnectedCallback() {
        this._connected = new Promise((resolve) => {
            this._resolveConnected = resolve;
        });
    }

    /**
     * Gets or sets the ordered hierarchy of categories to which the product belongs, ordered from least to most specific.
     *
     * @type {Category[]}
     */
    @api
    get categoryPath() {
        return this._categoryPath;
    }

    set categoryPath(newPath) {
        this._categoryPath = newPath;
        this.resolveCategoryPath(newPath || []);
    }

    get hasPrice() {
        return ((this.price || {}).negotiated || '').length > 0;
    }

    /**
     * Gets whether add to cart button should be displabled
     *
     * Add to cart button should be disabled if quantity is invalid,
     * if the cart is locked, or if the product is not in stock
     */
    get _isAddToCartDisabled() {
        return this._invalidQuantity || this.cartLocked || this.showerror;
    }

    handleNotifyBtn(){
        console.log('notify called');
        this.showSpinner = true;
        CreateCases()
            .then((result)=>{
                console.log('method call');
                console.log(result);
                const evt = new ShowToastEvent({
                    title: this.title,
                    message: this.message,
                    variant: this.variant,
                });
                this.dispatchEvent(evt);
                this.showSpinner = false;
            })
            .catch((e)=>{
                this.showSpinner = false;
                console.log(e);
            })

    }

    handleQuantityChange(event) {
        if (event.target.validity.valid && event.target.value) {
            this._invalidQuantity = false;
            this._quantityFieldValue = event.target.value;
            this.showcount = this.quantity - this._quantityFieldValue;
            if(this.quantity < this._quantityFieldValue){
                this.showerror = true;
            }
            else{
                this.showerror = false;
            }
        } else {
            this._invalidQuantity = true;
            this.quantity = this.quantity - this._quantityFieldValue;
        }
    }
    /**
     * Emits a notification that the user wants to add the item to their cart.
     *
     * @fires ProductDetailsDisplay#addtocart
     * @private
     */
    notifyAddToCart() {
        console.log('testing');
        console.log(typeof this._quantityFieldValue);
        this.showSpinner = true;
        let quantity = parseFloat(this._quantityFieldValue);
        let mapReqParams = {
            'ProductId' : this.recordId,
            'quantity' : quantity ,
            'cartId' : null
        };

        console.log('mapReqParams'+JSON.stringify (mapReqParams));
        updateInventoryFields({dataMap : mapReqParams})
        
        .then((result) => {
            console.log('add to cart')
            console.log(result) 
            if(result.isRequestSuccess == true){
                this.dispatchEvent(
                    new CustomEvent('addtocart', {
                        detail: {
                            quantity
                        }
                    })
                );
            } 
            this.showSpinner = false
        }).catch((e) => {
            console.log(e);
            this.showSpinner = false;
        })
    }

    /**
     * Emits a notification that the user wants to add the item to a new wishlist.
     *
     * @fires ProductDetailsDisplay#createandaddtolist
     * @private
     */
    notifyCreateAndAddToList() {
        this.dispatchEvent(new CustomEvent('createandaddtolist'));
    }

    /**
     * Updates the breadcrumb path for the product, resolving the categories to URLs for use as breadcrumbs.
     *
     * @param {Category[]} newPath
     *  The new category "path" for the product.
     */
    resolveCategoryPath(newPath) {
        const path = [homePage].concat(
            newPath.map((level) => ({
                name: level.name,
                type: 'standard__recordPage',
                attributes: {
                    actionName: 'view',
                    recordId: level.id
                }
            }))
        );

        this._connected
            .then(() => {
                const levelsResolved = path.map((level) =>
                    this[NavigationMixin.GenerateUrl]({
                        type: level.type,
                        attributes: level.attributes
                    }).then((url) => ({
                        name: level.name,
                        url: url
                    }))
                );

                return Promise.all(levelsResolved);
            })
            .then((levels) => {
                this._resolvedCategoryPath = levels;
            });
    }

    /**
     * Gets the iterable fields.
     *
     * @returns {IterableField[]}
     *  The ordered sequence of fields for display.
     *
     * @private
     */
    get _displayableFields() {
        // Enhance the fields with a synthetic ID for iteration.
        return (this.customFields || []).map((field, index) => ({
            ...field,
            id: index
        }));
    }
}