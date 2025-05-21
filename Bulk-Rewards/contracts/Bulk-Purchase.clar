;; Title: Bulk Purchase Discount Smart Contract
;; Description: A smart contract that provides discounts based on purchase quantity

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ITEM-EXISTS (err u101))
(define-constant ERR-ITEM-NOT-FOUND (err u102))
(define-constant ERR-INVALID-DISCOUNT (err u103))
(define-constant ERR-INVALID-PRICE (err u104))
(define-constant ERR-INSUFFICIENT-FUNDS (err u105))
(define-constant ERR-INVALID-QUANTITY (err u106))
(define-constant ERR-PURCHASE-FAILED (err u107))
(define-constant ERR-CONTRACT-LOCKED (err u108))
(define-constant ERR-EMPTY-LIST (err u109))

;; Data structures
(define-map items
  { item-id: uint }
  {
    name: (string-ascii 64),
    base-price: uint,
    available-quantity: uint
  }
)

(define-map discount-tiers
  { item-id: uint, min-quantity: uint }
  { discount-percentage: uint }
)

(define-map purchase-history
  { buyer: principal, purchase-id: uint }
  {
    item-id: uint,
    quantity: uint,
    price-paid: uint,
    timestamp: uint
  }
)

;; Variables
(define-data-var contract-owner principal tx-sender)
(define-data-var contract-locked bool false)
(define-data-var next-item-id uint u1)
(define-data-var next-purchase-id uint u1)
(define-data-var total-revenue uint u0)
(define-data-var purchase-count uint u0)

;; Read-only functions
(define-read-only (get-item (item-id uint))
  (map-get? items { item-id: item-id })
)

(define-read-only (get-discount-tier (item-id uint) (quantity uint))
  ;; Find the applicable discount tier
  (default-to 
    { discount-percentage: u0 }
    (map-get? discount-tiers { item-id: item-id, min-quantity: quantity })
  )
)

(define-read-only (calculate-discounted-price (item-id uint) (quantity uint))
  (let ((item-optional (get-item item-id)))
    (if (is-none item-optional)
      (err ERR-ITEM-NOT-FOUND)
      (let 
        ((item-value (unwrap-panic item-optional))
         (base-price (get base-price item-value))
         (discount-info (get-discount-tier item-id quantity))
         (discount-percentage (get discount-percentage discount-info))
         (discount-factor (- u100 discount-percentage))
         (total-base-price (* base-price quantity))
         (discounted-price (/ (* total-base-price discount-factor) u100)))
        
        (ok { 
          base-price: base-price,
          quantity: quantity,
          discount-percentage: discount-percentage, 
          final-price: discounted-price 
        })
      )
    )
  )
)

(define-read-only (get-purchase-by-id (purchase-id uint))
  (map-get? purchase-history { buyer: tx-sender, purchase-id: purchase-id })
)

(define-read-only (get-contract-owner)
  (var-get contract-owner)
)

(define-read-only (get-contract-stats)
  {
    total-revenue: (var-get total-revenue),
    purchase-count: (var-get purchase-count),
    contract-locked: (var-get contract-locked)
  }
)

;; Private helper functions for error checking
(define-private (check-item-exists (item-id uint))
  (if (is-some (get-item item-id))
    (ok true)
    (err ERR-ITEM-NOT-FOUND)
  )
)

;; Public functions
(define-public (add-item (name (string-ascii 64)) (base-price uint) (initial-quantity uint))
  (begin
    ;; Check authorization and contract state
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (not (var-get contract-locked)) ERR-CONTRACT-LOCKED)
    (asserts! (> base-price u0) ERR-INVALID-PRICE)
    
    ;; Add the new item
    (let ((new-item-id (var-get next-item-id)))
      (map-set items 
        { item-id: new-item-id }
        { 
          name: name,
          base-price: base-price,
          available-quantity: initial-quantity
        }
      )
      
      ;; Update the next item ID
      (var-set next-item-id (+ new-item-id u1))
      
      ;; Return the new item ID
      (ok new-item-id)
    )
  )
)

(define-public (update-item-quantity (item-id uint) (new-quantity uint))
  (begin 
    ;; Check authorization and contract state
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (not (var-get contract-locked)) ERR-CONTRACT-LOCKED)
    
    ;; First check if the item exists
    (unwrap! (check-item-exists item-id) ERR-ITEM-NOT-FOUND)
    
    ;; Now we can safely get and update the item
    (let ((item-value (unwrap-panic (get-item item-id))))
      (map-set items
        { item-id: item-id }
        (merge item-value { available-quantity: new-quantity })
      )
      (ok true)
    )
  )
)

(define-public (update-item-price (item-id uint) (new-price uint))
  (begin
    ;; Check authorization and contract state
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (not (var-get contract-locked)) ERR-CONTRACT-LOCKED)
    (asserts! (> new-price u0) ERR-INVALID-PRICE)
    
    ;; First check if the item exists
    (unwrap! (check-item-exists item-id) ERR-ITEM-NOT-FOUND)
    
    ;; Now we can safely get and update the item
    (let ((item-value (unwrap-panic (get-item item-id))))
      (map-set items
        { item-id: item-id }
        (merge item-value { base-price: new-price })
      )
      (ok true)
    )
  )
)

(define-public (set-discount-tier (item-id uint) (min-quantity uint) (discount-percentage uint))
  (begin
    ;; Check authorization and contract state
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (not (var-get contract-locked)) ERR-CONTRACT-LOCKED)
    
    ;; First check if the item exists
    (unwrap! (check-item-exists item-id) ERR-ITEM-NOT-FOUND)
    
    ;; Validate the inputs
    (asserts! (> min-quantity u0) ERR-INVALID-QUANTITY)
    (asserts! (<= discount-percentage u100) ERR-INVALID-DISCOUNT)
    
    ;; Set the discount tier
    (map-set discount-tiers
      { item-id: item-id, min-quantity: min-quantity }
      { discount-percentage: discount-percentage }
    )
    
    (ok true)
  )
)

(define-public (remove-discount-tier (item-id uint) (min-quantity uint))
  (begin
    ;; Check authorization and contract state
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (not (var-get contract-locked)) ERR-CONTRACT-LOCKED)
    
    ;; Delete the discount tier
    (map-delete discount-tiers { item-id: item-id, min-quantity: min-quantity })
    
    (ok true)
  )
)

(define-public (buy-item (item-id uint) (quantity uint))
  (begin
    ;; Validate the purchase
    (asserts! (not (var-get contract-locked)) ERR-CONTRACT-LOCKED)
    (asserts! (> quantity u0) ERR-INVALID-QUANTITY)
    
    ;; First check if the item exists
    (unwrap! (check-item-exists item-id) ERR-ITEM-NOT-FOUND)
    
    ;; Now we can safely get the item
    (let ((item-value (unwrap-panic (get-item item-id)))
          (available-quantity (get available-quantity (unwrap-panic (get-item item-id)))))
      
      ;; Check that enough items are available
      (asserts! (>= available-quantity quantity) ERR-INVALID-QUANTITY)
      
      ;; Calculate the price with discounts
      (let ((price-result (calculate-discounted-price item-id quantity)))
        (unwrap! price-result ERR-PURCHASE-FAILED)
        
        (let ((price-info (unwrap-panic price-result))
              (final-price (get final-price price-info))
              (purchase-id (var-get next-purchase-id)))
          
          ;; Process the payment (assuming STX payment)
          (try! (stx-transfer? final-price tx-sender (var-get contract-owner)))
          
          ;; Update the item's available quantity
          (map-set items
            { item-id: item-id }
            (merge item-value { available-quantity: (- available-quantity quantity) })
          )
          
          ;; Record the purchase
          (map-set purchase-history
            { buyer: tx-sender, purchase-id: purchase-id }
            {
              item-id: item-id,
              quantity: quantity,
              price-paid: final-price,
              timestamp: block-height
            }
          )
          
          ;; Update contract statistics
          (var-set total-revenue (+ (var-get total-revenue) final-price))
          (var-set purchase-count (+ (var-get purchase-count) u1))
          (var-set next-purchase-id (+ purchase-id u1))
          
          ;; Return purchase info
          (ok {
            purchase-id: purchase-id,
            item-id: item-id,
            name: (get name item-value),
            quantity: quantity,
            price-paid: final-price,
            discount-percentage: (get discount-percentage price-info)
          })
        )
      )
    )
  )
)

;; Single item purchase record function that returns a record
(define-private (process-purchase-item
  (purchase { item-id: uint, quantity: uint })
  (purchase-id uint))
  
  (let ((item-id (get item-id purchase))
        (quantity (get quantity purchase)))
  
    ;; Get the item
    (let ((item-value (unwrap-panic (get-item item-id))))
      (let ((name (get name item-value))
            (base-price (get base-price item-value))
            (available-quantity (get available-quantity item-value))
            (price-result (calculate-discounted-price item-id quantity)))
        
        ;; Calculate price
        (let ((price-info (unwrap-panic price-result))
              (final-price (get final-price price-info))
              (discount-percentage (get discount-percentage price-info)))
            
            ;; Update the item's available quantity
            (map-set items
              { item-id: item-id }
              { 
                name: name,
                base-price: base-price,
                available-quantity: (- available-quantity quantity) 
              }
            )
            
            ;; Record the purchase
            (map-set purchase-history
              { buyer: tx-sender, purchase-id: purchase-id }
              {
                item-id: item-id,
                quantity: quantity,
                price-paid: final-price,
                timestamp: block-height
              }
            )
            
            ;; Update contract statistics
            (var-set total-revenue (+ (var-get total-revenue) final-price))
            (var-set purchase-count (+ (var-get purchase-count) u1))
            
            ;; Return purchase info
            {
              purchase-id: purchase-id,
              item-id: item-id,
              name: name,
              quantity: quantity,
              price-paid: final-price,
              discount-percentage: discount-percentage
            })
      )
    )
  )
)

;; Helper function to calculate total price of purchases
(define-private (calculate-bulk-price
  (purchases (list 10 { item-id: uint, quantity: uint })))
  
  (fold calculate-item-price purchases u0)
)

;; Private helper to accumulate price for each item
(define-private (calculate-item-price
  (purchase { item-id: uint, quantity: uint })
  (accumulated-price uint))
  
  (let ((item-id (get item-id purchase))
        (quantity (get quantity purchase)))
    
    ;; Calculate price with discounts
    (let ((price-result (calculate-discounted-price item-id quantity)))
      (if (is-ok price-result)
        (let ((price-info (unwrap-panic price-result))
              (final-price (get final-price price-info)))
          (+ accumulated-price final-price))
        
        ;; If calculation fails, just return the accumulated price
        accumulated-price
      )
    )
  )
)

;; Private helper to check if all purchases are valid
(define-private (validate-purchases
  (purchases (list 10 { item-id: uint, quantity: uint })))
  
  (let ((result (fold validate-purchase purchases true)))
    result
  )
)

;; Private helper to validate a single purchase
(define-private (validate-purchase
  (purchase { item-id: uint, quantity: uint })
  (valid bool))
  
  ;; If already invalid, return false immediately
  (if (not valid)
    false
    
    (let ((item-id (get item-id purchase))
          (quantity (get quantity purchase)))
      
      ;; Check if item exists
      (if (is-none (get-item item-id))
        false
        
        (let ((item-value (unwrap-panic (get-item item-id)))
              (available-quantity (get available-quantity (unwrap-panic (get-item item-id)))))
          
          ;; Check quantity constraints
          (if (or (<= quantity u0) (< available-quantity quantity))
            false
            
            ;; Check price calculation
            (let ((price-result (calculate-discounted-price item-id quantity)))
              (if (is-err price-result)
                false
                true
              )
            )
          )
        )
      )
    )
  )
)

;; Helper function to process purchases one by one
(define-private (process-purchases
  (purchases (list 10 { item-id: uint, quantity: uint }))
  (start-id uint))
  
  (fold process-purchase-with-index 
        purchases 
        { 
          next-id: start-id, 
          results: (list)
        })
)

;; Helper to process each purchase with incrementing IDs
(define-private (process-purchase-with-index
  (purchase { item-id: uint, quantity: uint })
  (state { 
    next-id: uint, 
    results: (list 10 { 
      purchase-id: uint, 
      item-id: uint, 
      name: (string-ascii 64), 
      quantity: uint, 
      price-paid: uint, 
      discount-percentage: uint 
    })
  }))
  
  (let ((next-id (get next-id state))
        (current-results (get results state))
        (processed-item (process-purchase-item purchase next-id)))
    
    ;; Return updated state with new result and incremented ID
    {
      next-id: (+ next-id u1),
      results: (default-to 
                current-results
                (as-max-len? 
                  (append current-results processed-item)
                  u10))
    }
  )
)

;; Completely rewritten bulk purchase function with consistent return type
(define-public (bulk-purchase (purchases (list 10 { item-id: uint, quantity: uint })))
  (begin
    ;; Validate contract state
    (asserts! (not (var-get contract-locked)) ERR-CONTRACT-LOCKED)
    (asserts! (> (len purchases) u0) ERR-EMPTY-LIST)
    
    ;; First validate all purchases
    (asserts! (validate-purchases purchases) ERR-PURCHASE-FAILED)
    
    ;; Calculate total price
    (let ((total-price (calculate-bulk-price purchases)))
      ;; Process the payment
      (try! (stx-transfer? total-price tx-sender (var-get contract-owner)))
      
      ;; Process each purchase
      (let ((purchase-id (var-get next-purchase-id))
            (processed-results (process-purchases purchases purchase-id)))
        
        ;; Update next purchase ID
        (var-set next-purchase-id (+ purchase-id (len purchases)))
        
        ;; Return purchase info with consistent type
        (ok { 
          total-price: total-price,
          purchased-items: (get results processed-results)
        })
      )
    )
  )
)

;; Contract admin functions
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (lock-contract)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (var-set contract-locked true)
    (ok true)
  )
)

(define-public (unlock-contract)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (var-set contract-locked false)
    (ok true)
  )
)