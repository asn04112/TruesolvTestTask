import { LightningElement, api } from 'lwc';

export default class ItemTile extends LightningElement {
    @api item;

    get outOfStock() {
        return this.item.Quantity_In_Stock__c <= 0;
    }

  get itemImage() {
    return this.item.Image || 'https://www.salesforce.com/favicon.ico'; // simple test
}

    addToCart() {
        this.dispatchEvent(new CustomEvent('addtocart', {
            detail: { item: this.item }
        }));
    }

    showDetails() {
        this.dispatchEvent(new CustomEvent('showdetails', {
            detail: { itemId: this.item.Id }
        }));
    }
}