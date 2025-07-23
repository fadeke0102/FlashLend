;; FlashLend - Instant Bitcoin-backed microloans on Stacks
;; A decentralized lending protocol for quick STX loans with automatic liquidation

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u101))
(define-constant ERR_LOAN_NOT_FOUND (err u102))
(define-constant ERR_LOAN_EXPIRED (err u103))
(define-constant ERR_INSUFFICIENT_BALANCE (err u104))
(define-constant ERR_INVALID_AMOUNT (err u105))
(define-constant ERR_OVERFLOW (err u106))
(define-constant ERR_INVALID_DURATION (err u107))
(define-constant ERR_INVALID_RATIO (err u108))

;; Data Variables
(define-data-var loan-counter uint u0)
(define-data-var total-pool-balance uint u0)
(define-data-var collateral-ratio uint u150) ;; 150% collateralization required

;; Maximum values for safety
(define-constant MAX_AMOUNT u1000000000000) ;; 1M STX max
(define-constant MAX_DURATION u52560) ;; ~1 year in blocks
(define-constant MIN_RATIO u110) ;; 110% minimum
(define-constant MAX_RATIO u300) ;; 300% maximum

;; Data Maps
(define-map loans
  { loan-id: uint }
  {
    borrower: principal,
    collateral-amount: uint,
    loan-amount: uint,
    interest-rate: uint,
    created-at: uint,
    duration: uint,
    is-active: bool
  }
)

(define-map user-loans principal (list 10 uint))
(define-map lender-balances principal uint)

;; Read-only functions
(define-read-only (get-loan (loan-id uint))
  (map-get? loans { loan-id: loan-id })
)

(define-read-only (get-user-loans (user principal))
  (default-to (list) (map-get? user-loans user))
)

(define-read-only (get-pool-balance)
  (var-get total-pool-balance)
)

(define-read-only (get-collateral-ratio)
  (var-get collateral-ratio)
)

(define-read-only (calculate-required-collateral (loan-amount uint))
  (/ (* loan-amount (var-get collateral-ratio)) u100)
)

;; Private helper functions
(define-private (is-valid-amount (amount uint))
  (and (> amount u0) (<= amount MAX_AMOUNT))
)

(define-private (is-valid-duration (duration uint))
  (and (> duration u0) (<= duration MAX_DURATION))
)

(define-private (is-valid-ratio (ratio uint))
  (and (>= ratio MIN_RATIO) (<= ratio MAX_RATIO))
)

(define-private (safe-add (a uint) (b uint))
  (let ((result (+ a b)))
    (asserts! (>= result a) ERR_OVERFLOW)
    (ok result)
  )
)

;; Public functions
(define-public (deposit-to-pool (amount uint))
  (let ((current-balance (default-to u0 (map-get? lender-balances tx-sender))))
    (asserts! (is-valid-amount amount) ERR_INVALID_AMOUNT)
    (let ((new-balance (unwrap! (safe-add current-balance amount) ERR_OVERFLOW))
          (new-pool-balance (unwrap! (safe-add (var-get total-pool-balance) amount) ERR_OVERFLOW)))
      (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
      (map-set lender-balances tx-sender new-balance)
      (var-set total-pool-balance new-pool-balance)
      (ok amount)
    )
  )
)

(define-public (withdraw-from-pool (amount uint))
  (let ((current-balance (default-to u0 (map-get? lender-balances tx-sender))))
    (asserts! (is-valid-amount amount) ERR_INVALID_AMOUNT)
    (asserts! (>= current-balance amount) ERR_INSUFFICIENT_BALANCE)
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    (map-set lender-balances tx-sender (- current-balance amount))
    (var-set total-pool-balance (- (var-get total-pool-balance) amount))
    (ok amount)
  )
)

(define-public (request-loan (loan-amount uint) (duration uint))
  (let (
    (loan-id (+ (var-get loan-counter) u1))
    (required-collateral (calculate-required-collateral loan-amount))
    (current-user-loans (get-user-loans tx-sender))
  )
    (asserts! (is-valid-amount loan-amount) ERR_INVALID_AMOUNT)
    (asserts! (is-valid-duration duration) ERR_INVALID_DURATION)
    (asserts! (>= (var-get total-pool-balance) loan-amount) ERR_INSUFFICIENT_BALANCE)

    ;; Transfer collateral from borrower to contract
    (try! (stx-transfer? required-collateral tx-sender (as-contract tx-sender)))

    ;; Transfer loan amount to borrower
    (try! (as-contract (stx-transfer? loan-amount tx-sender tx-sender)))

    ;; Create loan record
    (map-set loans
      { loan-id: loan-id }
      {
        borrower: tx-sender,
        collateral-amount: required-collateral,
        loan-amount: loan-amount,
        interest-rate: u10, ;; 10% interest
        created-at: block-height,
        duration: duration,
        is-active: true
      }
    )

    ;; Update user loans list
    (map-set user-loans tx-sender (unwrap-panic (as-max-len? (append current-user-loans loan-id) u10)))

    ;; Update counters
    (var-set loan-counter loan-id)
    (var-set total-pool-balance (- (var-get total-pool-balance) loan-amount))

    (ok loan-id)
  )
)

(define-public (repay-loan (loan-id uint))
  (let ((loan-data (unwrap! (get-loan loan-id) ERR_LOAN_NOT_FOUND)))
    (asserts! (get is-active loan-data) ERR_LOAN_NOT_FOUND)
    (asserts! (is-eq (get borrower loan-data) tx-sender) ERR_UNAUTHORIZED)

    (let (
      (loan-amount (get loan-amount loan-data))
      (interest-amount (/ (* loan-amount (get interest-rate loan-data)) u100))
      (total-repayment (+ loan-amount interest-amount))
      (collateral-amount (get collateral-amount loan-data))
      (new-pool-balance (unwrap! (safe-add (var-get total-pool-balance) total-repayment) ERR_OVERFLOW))
    )
      ;; Transfer repayment from borrower to contract
      (try! (stx-transfer? total-repayment tx-sender (as-contract tx-sender)))

      ;; Return collateral to borrower
      (try! (as-contract (stx-transfer? collateral-amount tx-sender tx-sender)))

      ;; Mark loan as inactive
      (map-set loans
        { loan-id: loan-id }
        (merge loan-data { is-active: false })
      )

      ;; Update pool balance
      (var-set total-pool-balance new-pool-balance)

      (ok total-repayment)
    )
  )
)

(define-public (liquidate-loan (loan-id uint))
  (let ((loan-data (unwrap! (get-loan loan-id) ERR_LOAN_NOT_FOUND)))
    (asserts! (get is-active loan-data) ERR_LOAN_NOT_FOUND)

    (let (
      (created-at (get created-at loan-data))
      (duration (get duration loan-data))
      (expiry-block (+ created-at duration))
      (new-pool-balance (unwrap! (safe-add (var-get total-pool-balance) (get collateral-amount loan-data)) ERR_OVERFLOW))
    )
      (asserts! (>= block-height expiry-block) ERR_LOAN_EXPIRED)

      ;; Mark loan as inactive
      (map-set loans
        { loan-id: loan-id }
        (merge loan-data { is-active: false })
      )

      ;; Collateral stays in contract as penalty
      (var-set total-pool-balance new-pool-balance)

      (ok loan-id)
    )
  )
)

;; Admin functions
(define-public (set-collateral-ratio (new-ratio uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-valid-ratio new-ratio) ERR_INVALID_RATIO)
    (var-set collateral-ratio new-ratio)
    (ok new-ratio)
  )
)