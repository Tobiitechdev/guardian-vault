;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_WALLET_NOT_FOUND (err u404))
(define-constant ERR_INVALID_GUARDIAN (err u400))
(define-constant ERR_INSUFFICIENT_GUARDIANS (err u402))
(define-constant ERR_RECOVERY_ALREADY_ACTIVE (err u403))
(define-constant ERR_NO_ACTIVE_RECOVERY (err u405))
(define-constant ERR_ALREADY_VOTED (err u406))
(define-constant RECOVERY_TIMEOUT u144) ;; ~24 hours in blocks

;; Data structures
(define-map wallets
  { wallet-id: uint }
  {
    owner: principal,
    guardians: (list 10 principal),
    threshold: uint,
    is-active: bool,
    created-at: uint
  }
)

(define-map recovery-requests
  { wallet-id: uint }
  {
    new-owner: principal,
    votes: (list 10 principal),
    created-at: uint,
    is-active: bool
  }
)

(define-map wallet-balances
  { wallet-id: uint }
  { balance: uint }
)

;; Data variables
(define-data-var next-wallet-id uint u1)

;; Helper functions
(define-private (is-guardian (wallet-id uint) (guardian principal))
  (let ((wallet-data (unwrap! (map-get? wallets { wallet-id: wallet-id }) false)))
    (is-some (index-of (get guardians wallet-data) guardian))
  )
)

(define-private (has-voted (wallet-id uint) (voter principal))
  (let ((recovery-data (map-get? recovery-requests { wallet-id: wallet-id })))
    (match recovery-data
      some-recovery (is-some (index-of (get votes some-recovery) voter))
      false
    )
  )
)

(define-private (count-votes (wallet-id uint))
  (let ((recovery-data (map-get? recovery-requests { wallet-id: wallet-id })))
    (match recovery-data
      some-recovery (len (get votes some-recovery))
      u0
    )
  )
)

;; Public functions
(define-public (create-wallet (guardians (list 10 principal)) (threshold uint))
  (let (
    (wallet-id (var-get next-wallet-id))
    (guardian-count (len guardians))
  )
    (asserts! (and (>= guardian-count u2) (<= guardian-count u10)) ERR_INVALID_GUARDIAN)
    (asserts! (and (>= threshold u1) (<= threshold guardian-count)) ERR_INVALID_GUARDIAN)
    
    (map-set wallets
      { wallet-id: wallet-id }
      {
        owner: tx-sender,
        guardians: guardians,
        threshold: threshold,
        is-active: true,
        created-at: block-height
      }
    )
    
    (map-set wallet-balances
      { wallet-id: wallet-id }
      { balance: u0 }
    )
    
    (var-set next-wallet-id (+ wallet-id u1))
    (ok wallet-id)
  )
)

(define-public (deposit (wallet-id uint) (amount uint))
  (let (
    (wallet-data (unwrap! (map-get? wallets { wallet-id: wallet-id }) ERR_WALLET_NOT_FOUND))
    (current-balance (default-to { balance: u0 } (map-get? wallet-balances { wallet-id: wallet-id })))
  )
    (asserts! (get is-active wallet-data) ERR_UNAUTHORIZED)
    (asserts! (is-eq tx-sender (get owner wallet-data)) ERR_UNAUTHORIZED)
    
    (map-set wallet-balances
      { wallet-id: wallet-id }
      { balance: (+ (get balance current-balance) amount) }
    )
    (ok true)
  )
)

(define-public (withdraw (wallet-id uint) (amount uint))
  (let (
    (wallet-data (unwrap! (map-get? wallets { wallet-id: wallet-id }) ERR_WALLET_NOT_FOUND))
    (current-balance (default-to { balance: u0 } (map-get? wallet-balances { wallet-id: wallet-id })))
  )
    (asserts! (get is-active wallet-data) ERR_UNAUTHORIZED)
    (asserts! (is-eq tx-sender (get owner wallet-data)) ERR_UNAUTHORIZED)
    (asserts! (>= (get balance current-balance) amount) ERR_UNAUTHORIZED)
    
    (map-set wallet-balances
      { wallet-id: wallet-id }
      { balance: (- (get balance current-balance) amount) }
    )
    (ok amount)
  )
)

(define-public (initiate-recovery (wallet-id uint) (new-owner principal))
  (let ((wallet-data (unwrap! (map-get? wallets { wallet-id: wallet-id }) ERR_WALLET_NOT_FOUND)))
    (asserts! (get is-active wallet-data) ERR_UNAUTHORIZED)
    (asserts! (is-guardian wallet-id tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? recovery-requests { wallet-id: wallet-id })) ERR_RECOVERY_ALREADY_ACTIVE)
    
    (map-set recovery-requests
      { wallet-id: wallet-id }
      {
        new-owner: new-owner,
        votes: (list tx-sender),
        created-at: block-height,
        is-active: true
      }
    )
    (ok true)
  )
)

(define-public (vote-recovery (wallet-id uint))
  (let (
    (wallet-data (unwrap! (map-get? wallets { wallet-id: wallet-id }) ERR_WALLET_NOT_FOUND))
    (recovery-data (unwrap! (map-get? recovery-requests { wallet-id: wallet-id }) ERR_NO_ACTIVE_RECOVERY))
  )
    (asserts! (get is-active recovery-data) ERR_NO_ACTIVE_RECOVERY)
    (asserts! (is-guardian wallet-id tx-sender) ERR_UNAUTHORIZED)
    (asserts! (not (has-voted wallet-id tx-sender)) ERR_ALREADY_VOTED)
    (asserts! (< (- block-height (get created-at recovery-data)) RECOVERY_TIMEOUT) ERR_NO_ACTIVE_RECOVERY)
    
    (let ((updated-votes (unwrap-panic (as-max-len? (append (get votes recovery-data) tx-sender) u10))))
      (map-set recovery-requests
        { wallet-id: wallet-id }
        (merge recovery-data { votes: updated-votes })
      )
      
      ;; Check if threshold reached
      (if (>= (len updated-votes) (get threshold wallet-data))
        (begin
          (map-set wallets
            { wallet-id: wallet-id }
            (merge wallet-data { owner: (get new-owner recovery-data) })
          )
          (map-delete recovery-requests { wallet-id: wallet-id })
          (ok "recovery-completed")
        )
        (ok "vote-recorded")
      )
    )
  )
)

(define-public (cancel-recovery (wallet-id uint))
  (let (
    (wallet-data (unwrap! (map-get? wallets { wallet-id: wallet-id }) ERR_WALLET_NOT_FOUND))
    (recovery-data (unwrap! (map-get? recovery-requests { wallet-id: wallet-id }) ERR_NO_ACTIVE_RECOVERY))
  )
    (asserts! (is-eq tx-sender (get owner wallet-data)) ERR_UNAUTHORIZED)
    (map-delete recovery-requests { wallet-id: wallet-id })
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-wallet (wallet-id uint))
  (map-get? wallets { wallet-id: wallet-id })
)

(define-read-only (get-balance (wallet-id uint))
  (map-get? wallet-balances { wallet-id: wallet-id })
)

(define-read-only (get-recovery-status (wallet-id uint))
  (map-get? recovery-requests { wallet-id: wallet-id })
)

(define-read-only (get-vote-count (wallet-id uint))
  (ok (count-votes wallet-id))
)