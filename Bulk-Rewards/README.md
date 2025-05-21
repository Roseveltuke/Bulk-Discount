# Bulk Purchase Discount Smart Contract

A Clarity smart contract for managing inventory with dynamic pricing based on purchase quantities.

## Overview

This smart contract implements a bulk purchase discount system that allows:
- Inventory management with dynamic pricing
- Tiered discounts based on purchase quantity
- Single and bulk purchase functionality
- Purchase history tracking

## Features

- **Inventory Management**: Add, update, and track items
- **Dynamic Pricing**: Set base prices and configure quantity-based discount tiers
- **Purchase Processing**: Support for both single item and bulk purchases
- **Ownership Controls**: Contract ownership management and locking mechanisms
- **Statistics Tracking**: Revenue and purchase count tracking

## Error Codes

| Code | Description |
|------|-------------|
| u100 | Not authorized |
| u101 | Item already exists |
| u102 | Item not found |
| u103 | Invalid discount |
| u104 | Invalid price |
| u105 | Insufficient funds |
| u106 | Invalid quantity |
| u107 | Purchase failed |
| u108 | Contract locked |
| u109 | Empty list |

## Data Structures

### Items Map
Stores item information:
- `name`: Item name (64 ASCII characters max)
- `base-price`: Base price in microSTX
- `available-quantity`: Available inventory

### Discount Tiers Map
Configures quantity-based discounts:
- `item-id`: References the item
- `min-quantity`: Minimum purchase quantity for discount
- `discount-percentage`: Percentage discount (0-100)

### Purchase History Map
Records transaction history:
- `buyer`: Principal who made the purchase
- `purchase-id`: Unique identifier for the purchase
- `item-id`: Item purchased
- `quantity`: Quantity purchased
- `price-paid`: Final price paid after discounts
- `timestamp`: Block height when purchase was made

## Public Functions

### Item Management

```clarity
(add-item (name (string-ascii 64)) (base-price uint) (initial-quantity uint))
```
Adds a new item to the inventory.

```clarity
(update-item-quantity (item-id uint) (new-quantity uint))
```
Updates the available quantity of an existing item.

```clarity
(update-item-price (item-id uint) (new-price uint))
```
Updates the base price of an existing item.

### Discount Management

```clarity
(set-discount-tier (item-id uint) (min-quantity uint) (discount-percentage uint))
```
Sets a discount tier for an item based on minimum purchase quantity.

```clarity
(remove-discount-tier (item-id uint) (min-quantity uint))
```
Removes a specific discount tier.

### Purchase Functions

```clarity
(buy-item (item-id uint) (quantity uint))
```
Purchases a single item type with specified quantity.

```clarity
(bulk-purchase (purchases (list 10 { item-id: uint, quantity: uint })))
```
Purchases multiple items in a single transaction (up to 10 different items).

### Contract Administration

```clarity
(transfer-ownership (new-owner principal))
```
Transfers contract ownership to a new principal.

```clarity
(lock-contract)
```
Locks the contract, preventing further modifications or purchases.

```clarity
(unlock-contract)
```
Unlocks the contract, allowing modifications and purchases.

## Read-Only Functions

```clarity
(get-item (item-id uint))
```
Retrieves item information.

```clarity
(get-discount-tier (item-id uint) (quantity uint))
```
Gets the applicable discount tier for an item and quantity.

```clarity
(calculate-discounted-price (item-id uint) (quantity uint))
```
Calculates the final price after applying quantity-based discounts.

```clarity
(get-purchase-by-id (purchase-id uint))
```
Retrieves a purchase record by ID.

```clarity
(get-contract-owner)
```
Gets the current contract owner.

```clarity
(get-contract-stats)
```
Retrieves contract statistics (revenue, purchase count, lock status).

## Usage Examples

### Setting Up Items and Discounts

```clarity
;; Add a new item: "T-Shirt" with base price 50 STX and 100 available
(contract-call? .bulk-purchase-discount add-item "T-Shirt" u50000000 u100)

;; Set discount tiers:
;; 10% discount for purchasing 5 or more
(contract-call? .bulk-purchase-discount set-discount-tier u1 u5 u10)
;; 20% discount for purchasing 10 or more
(contract-call? .bulk-purchase-discount set-discount-tier u1 u10 u20)
```

### Making Purchases

```clarity
;; Purchase 7 T-shirts (will get 10% discount)
(contract-call? .bulk-purchase-discount buy-item u1 u7)

;; Make a bulk purchase of multiple items
(contract-call? .bulk-purchase-discount bulk-purchase 
  (list 
    {item-id: u1, quantity: u5}
    {item-id: u2, quantity: u3}
  )
)
```