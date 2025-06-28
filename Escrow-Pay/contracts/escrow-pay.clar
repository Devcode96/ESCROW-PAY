;; Escrow Payment Contract
;; Enables secure trustless payments between parties

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u500))
(define-constant err-escrow-not-found (err u501))
(define-constant err-unauthorized (err u502))
(define-constant err-already-released (err u503))
(define-constant err-not-expired (err u504))
(define-constant err-insufficient-payment (err u505))
(define-constant err-invalid-fee (err u506))

(define-data-var escrow-counter uint u0)
(define-data-var platform-fee uint u100) ;; 1% platform fee

(define-map escrows uint {
  buyer: principal,
  seller: principal,
  arbiter: (optional principal),
  amount: uint,
  description: (string-ascii 200),
  status: (string-ascii 20),
  created-at: uint,
  timeout: uint,
  buyer-approved: bool,
  seller-approved: bool,
  arbiter-decision: (optional bool)
})

(define-map escrow-messages {escrow-id: uint, sender: principal} (string-ascii 500))

(define-read-only (get-escrow (escrow-id uint))
  (map-get? escrows escrow-id)
)

(define-read-only (get-escrow-message (escrow-id uint) (sender principal))
  (map-get? escrow-messages {escrow-id: escrow-id, sender: sender})
)

(define-read-only (get-platform-fee)
  (var-get platform-fee)
)

(define-public (create-escrow (seller principal) (arbiter (optional principal)) (amount uint) (description (string-ascii 200)) (timeout-blocks uint))
  (let ((escrow-id (+ (var-get escrow-counter) u1)))
    (asserts! (> amount u0) err-insufficient-payment)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    (map-set escrows escrow-id {
      buyer: tx-sender,
      seller: seller,
      arbiter: arbiter,
      amount: amount,
      description: description,
      status: "active",
      created-at: stacks-block-height,
      timeout: (+ stacks-block-height timeout-blocks),
      buyer-approved: false,
      seller-approved: false,
      arbiter-decision: none
    })
    
    (var-set escrow-counter escrow-id)
    (ok escrow-id)
  )
)

(define-public (approve-release (escrow-id uint))
  (let ((escrow (unwrap! (get-escrow escrow-id) err-escrow-not-found)))
    (asserts! (is-eq (get status escrow) "active") err-already-released)
    
    (if (is-eq tx-sender (get buyer escrow))
      (begin
        (map-set escrows escrow-id (merge escrow {buyer-approved: true}))
        (ok true)
      )
      (if (is-eq tx-sender (get seller escrow))
        (begin
          (map-set escrows escrow-id (merge escrow {seller-approved: true}))
          (ok true)
        )
        err-unauthorized
      )
    )
  )
)

(define-public (release-funds (escrow-id uint))
  (let ((escrow (unwrap! (get-escrow escrow-id) err-escrow-not-found))
        (fee (/ (* (get amount escrow) (var-get platform-fee)) u10000))
        (seller-amount (- (get amount escrow) fee)))
    
    (asserts! (is-eq (get status escrow) "active") err-already-released)
    (asserts! (and (get buyer-approved escrow) (get seller-approved escrow)) err-unauthorized)
    
    ;; Transfer funds to seller
    (try! (as-contract (stx-transfer? seller-amount tx-sender (get seller escrow))))
    
    ;; Transfer fee to contract owner
    (try! (as-contract (stx-transfer? fee tx-sender contract-owner)))
    
    ;; Update escrow status
    (map-set escrows escrow-id (merge escrow {status: "completed"}))
    
    (ok seller-amount)
  )
)

(define-public (request-refund (escrow-id uint))
  (let ((escrow (unwrap! (get-escrow escrow-id) err-escrow-not-found)))
    (asserts! (is-eq tx-sender (get buyer escrow)) err-unauthorized)
    (asserts! (is-eq (get status escrow) "active") err-already-released)
    (asserts! (>= stacks-block-height (get timeout escrow)) err-not-expired)
    
    ;; Refund to buyer
    (try! (as-contract (stx-transfer? (get amount escrow) tx-sender (get buyer escrow))))
    
    ;; Update escrow status
    (map-set escrows escrow-id (merge escrow {status: "refunded"}))
    
    (ok (get amount escrow))
  )
)

(define-public (arbiter-resolve (escrow-id uint) (release-to-seller bool))
  (let ((escrow (unwrap! (get-escrow escrow-id) err-escrow-not-found))
        (arbiter (unwrap! (get arbiter escrow) err-unauthorized)))
    
    (asserts! (is-eq tx-sender arbiter) err-unauthorized)
    (asserts! (is-eq (get status escrow) "active") err-already-released)
    
    (if release-to-seller
      (let ((fee (/ (* (get amount escrow) (var-get platform-fee)) u10000))
            (seller-amount (- (get amount escrow) fee)))
        (try! (as-contract (stx-transfer? seller-amount tx-sender (get seller escrow))))
        (try! (as-contract (stx-transfer? fee tx-sender contract-owner)))
        (map-set escrows escrow-id (merge escrow {status: "completed", arbiter-decision: (some true)}))
        (ok true)
      )
      (begin
        (try! (as-contract (stx-transfer? (get amount escrow) tx-sender (get buyer escrow))))
        (map-set escrows escrow-id (merge escrow {status: "refunded", arbiter-decision: (some false)}))
        (ok false)
      )
    )
  )
)

(define-public (add-message (escrow-id uint) (message (string-ascii 500)))
  (let ((escrow (unwrap! (get-escrow escrow-id) err-escrow-not-found)))
    (asserts! (or (is-eq tx-sender (get buyer escrow))
                  (is-eq tx-sender (get seller escrow))
                  (and (is-some (get arbiter escrow))
                       (is-eq tx-sender (unwrap-panic (get arbiter escrow))))) err-unauthorized)
    
    (map-set escrow-messages {escrow-id: escrow-id, sender: tx-sender} message)
    (ok true)
  )
)

(define-public (set-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-fee u500) err-invalid-fee) ;; Max 5% fee
    (var-set platform-fee new-fee)
    (ok true)
  )
)
