import { LightningElement, api } from 'lwc';

export default class ItemTileList extends LightningElement {
    @api items;

    handleAddToCart(event) {
        this.dispatchEvent(new CustomEvent('addtocart', { detail: event.detail }));
    }
    handleShowDetails(event) {
        this.dispatchEvent(new CustomEvent('showdetails', { detail: event.detail }));
    }
}