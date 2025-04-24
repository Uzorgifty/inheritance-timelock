;; offspring-trust-fund
;; This smart contract enables parents to establish trust funds for their children, locking funds until a specified maturity date.
;; The contract handles account creation, funding, scheduled withdrawals, emergency access, and administrative controls.

;; Constants and Maps

;; Contract ownership and access
(define-constant contract-owner tx-sender)
(define-constant contract-self (as-contract tx-sender))

;; Time constants
(define-constant blocks-per-year (* u365 u144))

;; Fee structure
(define-constant registration-fee u5000000)
(define-constant minimum-deposit u5000000)
(define-constant standard-withdrawal-fee-percent u2)
(define-constant emergency-withdrawal-fee-percent u10)

;; Revenue tracking
(define-data-var accumulated-fees uint u0)

;; Trust account data structure
(define-map trust-account {trustee: principal, beneficiary-id: (string-ascii 24)}
    {
        beneficiary-address: principal,
        beneficiary-name: (string-ascii 24),
        maturity-block-height: uint,
        fund-balance: uint,
        authorized-managers: (list 5 principal)
    }
)

;;Read Functions
;; Get the total balance held by the contract
(define-read-only (get-contract-balance)
    (stx-get-balance contract-self)
)

;; Retrieve information about a specific trust account
(define-read-only (get-trust-account (trustee principal) (beneficiary-id (string-ascii 24)))
    (map-get? trust-account {trustee: trustee, beneficiary-id: beneficiary-id})
)

;; Get the total accumulated fees
(define-read-only (get-accumulated-fees)
    (var-get accumulated-fees)
)

;; Write Functions

;; Create a new trust account for a child
(define-public (create-trust-account
                    (beneficiary-id (string-ascii 24))
                    (beneficiary-address principal)
                    (lock-duration-years uint)
                    (initial-deposit uint)
                )
    (let
        (
            (current-accumulated-fees (var-get accumulated-fees))
            (existing-account (map-get? trust-account {trustee: tx-sender, beneficiary-id: beneficiary-id}))
            (total-required-payment (+ initial-deposit registration-fee))
        )
        (asserts! (is-none existing-account) (err u"ERR-ACCOUNT-ALREADY-EXISTS"))
        (asserts! (>= initial-deposit minimum-deposit) (err u"ERR-MINIMUM-DEPOSIT-REQUIRED"))
        (asserts! (>= (stx-get-balance tx-sender) total-required-payment) (err u"ERR-INSUFFICIENT-BALANCE"))
        
        (unwrap! (stx-transfer? total-required-payment tx-sender contract-self) (err u"ERR-PAYMENT-TRANSFER-FAILED"))
        (var-set accumulated-fees (+ current-accumulated-fees registration-fee))
        
        (ok (map-set trust-account {trustee: tx-sender, beneficiary-id: beneficiary-id}
            {
                beneficiary-address: beneficiary-address,
                beneficiary-name: beneficiary-id,
                maturity-block-height: (+ block-height (* blocks-per-year lock-duration-years)),
                fund-balance: initial-deposit,
                authorized-managers: (list tx-sender)
            }
        ))
    )
)

;; Add additional funds to an existing trust account
(define-public (deposit-to-trust (trustee principal) (beneficiary-id (string-ascii 24)) (deposit-amount uint))
    (let
        (
            (account-details (unwrap!
                (map-get? trust-account {trustee: trustee, beneficiary-id: beneficiary-id})
                (err u"ERR-ACCOUNT-NOT-FOUND")
            ))
            (current-balance (get fund-balance account-details))
        )
        (unwrap!
            (stx-transfer? deposit-amount tx-sender contract-self)
            (err u"ERR-DEPOSIT-TRANSFER-FAILED")
        )
        (ok (map-set trust-account {trustee: tx-sender, beneficiary-id: beneficiary-id}
            (merge
                account-details
                {fund-balance: (+ deposit-amount current-balance)}
            )
        ))
    )
)

;; Beneficiary withdrawal function for matured trust accounts
(define-public (beneficiary-withdrawal (trustee principal) (beneficiary-id (string-ascii 24)))
    (let
        (
            (current-accumulated-fees (var-get accumulated-fees))
            (account-details (unwrap!
                (map-get? trust-account {trustee: trustee, beneficiary-id: beneficiary-id})
                (err u"ERR-ACCOUNT-NOT-FOUND")
            ))
            (beneficiary-wallet (get beneficiary-address account-details))
            (trust-balance (get fund-balance account-details))
            (maturity-height (get maturity-block-height account-details))
            (fee-amount (/ (* trust-balance standard-withdrawal-fee-percent) u100))
            (withdrawal-amount (- trust-balance fee-amount))
        )
        (asserts! (is-eq tx-sender beneficiary-wallet) (err u"ERR-UNAUTHORIZED-BENEFICIARY"))
        (asserts! (>= block-height maturity-height) (err u"ERR-ACCOUNT-NOT-MATURED"))
        
        (unwrap!
            (as-contract (stx-transfer? withdrawal-amount tx-sender beneficiary-wallet))
            (err u"ERR-WITHDRAWAL-TRANSFER-FAILED")
        )
        
        (var-set accumulated-fees (+ current-accumulated-fees fee-amount))
        (ok (map-delete trust-account {trustee: trustee, beneficiary-id: beneficiary-id}))
    )
)

;; Update beneficiary wallet address
(define-public (update-beneficiary-address (trustee principal) (beneficiary-id (string-ascii 24)) (new-address principal))
    (let 
        (
            (account-details (unwrap!
                (map-get? trust-account {trustee: trustee, beneficiary-id: beneficiary-id})
                (err u"ERR-ACCOUNT-NOT-FOUND")
            ))
            (manager-list (get authorized-managers account-details))
        )
        (asserts!
            (is-some (index-of manager-list tx-sender))
            (err u"ERR-UNAUTHORIZED-MANAGER")
        )
        (ok (map-set trust-account {trustee: tx-sender, beneficiary-id: beneficiary-id}
            (merge
                account-details
                {beneficiary-address: new-address}
            )
        ))
    )
)

;; Emergency withdrawal for trustees or authorized managers
(define-public (trustee-emergency-withdrawal (trustee principal) (beneficiary-id (string-ascii 24)))
    (let
        (
            (current-accumulated-fees (var-get accumulated-fees))
            (account-details (unwrap!
                (map-get? trust-account {trustee: trustee, beneficiary-id: beneficiary-id})
                (err u"ERR-ACCOUNT-NOT-FOUND")
            ))
            (trust-balance (get fund-balance account-details))
            (maturity-height (get maturity-block-height account-details))
            (withdrawal-fee 
                (if 
                    (>= block-height maturity-height) 
                    (/ (* trust-balance standard-withdrawal-fee-percent) u100)
                    (/ (* trust-balance emergency-withdrawal-fee-percent) u100)
                )
            )
            (withdrawal-amount (- trust-balance withdrawal-fee))
            (manager-list (get authorized-managers account-details))
        )
        (asserts!
            (or (is-eq tx-sender trustee) (is-some (index-of manager-list tx-sender)))
            (err u"ERR-UNAUTHORIZED-TRUSTEE-OR-MANAGER")
        )
        
        (unwrap!
            (as-contract (stx-transfer? withdrawal-amount tx-sender tx-sender))
            (err u"ERR-EMERGENCY-WITHDRAWAL-FAILED")
        )
        
        (var-set accumulated-fees (+ current-accumulated-fees withdrawal-fee))
        (ok (map-delete trust-account {trustee: trustee, beneficiary-id: beneficiary-id}))
    )
)

;; Contract owner withdrawal of accumulated fees
(define-public (withdraw-contract-fees)
    (let
        (
            (fee-total (var-get accumulated-fees))
        )
        (asserts! (is-eq tx-sender contract-owner) (err u"ERR-UNAUTHORIZED-OWNER"))
        (asserts! (> fee-total u0) (err u"ERR-NO-FEES-AVAILABLE"))
        
        (unwrap! 
            (as-contract (stx-transfer? fee-total tx-sender contract-owner))
            (err u"ERR-FEE-WITHDRAWAL-FAILED")    
        )
        
        (ok (var-set accumulated-fees u0))
    )
)

;; Trust Management Functions

;; Add an authorized manager to a trust account
(define-public (add-trust-manager (trustee principal) (beneficiary-id (string-ascii 24)) (manager-address principal))
    (let
        (
            (account-details (unwrap!
                (map-get? trust-account {trustee: trustee, beneficiary-id: beneficiary-id})
                (err u"ERR-ACCOUNT-NOT-FOUND")
            ))
            (current-managers (get authorized-managers account-details))
        )
        (asserts! (is-eq tx-sender trustee) (err u"ERR-UNAUTHORIZED-TRUSTEE"))
        (asserts! (is-none (index-of current-managers manager-address)) (err u"ERR-MANAGER-ALREADY-EXISTS"))
        
        (ok (map-set trust-account {trustee: tx-sender, beneficiary-id: beneficiary-id}
            (merge
                account-details
                {authorized-managers: (unwrap!
                    (as-max-len? (append current-managers manager-address) u5)
                    (err u"ERR-MANAGER-LIST-FULL")
                )}
            )
        ))
    )
)

;; Remove an authorized manager from a trust account
(define-public (remove-trust-manager (trustee principal) (beneficiary-id (string-ascii 24)) (manager-address principal))
    (let
        (
            (account-details (unwrap!
                (map-get? trust-account {trustee: trustee, beneficiary-id: beneficiary-id})
                (err u"ERR-ACCOUNT-NOT-FOUND")
            ))
            (current-managers (get authorized-managers account-details))
        )
        (asserts! (is-eq tx-sender trustee) (err u"ERR-UNAUTHORIZED-TRUSTEE"))
        (asserts! (is-some (index-of current-managers manager-address)) (err u"ERR-MANAGER-NOT-FOUND"))
        
        (ok (map-set trust-account {trustee: trustee, beneficiary-id: beneficiary-id}
            (merge
                account-details
                {authorized-managers: (get filtered-managers 
                    (fold filter-manager current-managers {manager-to-remove: manager-address, filtered-managers: (list)})
                )}
            )
        ))
    )
)

;; Helper function to filter out a manager from the list
(define-private (filter-manager (manager principal) (state {manager-to-remove: principal, filtered-managers: (list 5 principal)}))
    (merge state {filtered-managers:
        (if (is-eq manager (get manager-to-remove state))
            (get filtered-managers state)
            (unwrap-panic (as-max-len? (append (get filtered-managers state) manager) u5))
        )}
    )
)