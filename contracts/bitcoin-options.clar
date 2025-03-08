;; Title: Bitcoin Options Trading Platform on Stacks L2
;; Summary: Decentralized Bitcoin option contracts with sBTC settlement, automated execution, and collateral management via Stacks smart contracts
;; Description: 
;; A trustless Bitcoin derivatives platform leveraging Stacks Layer 2 smart contracts for:
;; - Peer-to-peer BTC option trading using sBTC (wrapped Bitcoin)
;; - Automated collateral management with on-chain price oracles
;; - Non-custodial settlement directly on Bitcoin's security layer
;; - Programmatic option expiration/exercise via Stacks-Bitcoin bridge
;; Built using Clarity smart contracts for Bitcoin-native DeFi, enabling complex financial instruments while maintaining compatibility with Bitcoin's core protocol through Stacks' Layer 2 design.

;; Contract Owner
(define-constant CONTRACT_OWNER tx-sender)

;; Parameter Limits
(define-constant MAX_FEE_BASIS_POINTS u10000) ;; 100%
(define-constant MAX_COLLATERAL_RATIO u1000)  ;; 1000%
(define-constant MIN_DEPOSIT_AMOUNT u1000)    ;; Minimum deposit
(define-constant MAX_DEPOSIT_AMOUNT u100000000000) ;; Maximum deposit
(define-constant MIN_VALIDITY_WINDOW u10)     ;; Minimum blocks for price validity
(define-constant MAX_VALIDITY_WINDOW u1440)   ;; Maximum blocks (~24 hours)

;; Error Codes
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INVALID_AMOUNT (err u101))
(define-constant ERR_INSUFFICIENT_BALANCE (err u102))
(define-constant ERR_OPTION_NOT_FOUND (err u103))
(define-constant ERR_OPTION_EXPIRED (err u104))
(define-constant ERR_INVALID_STRIKE_PRICE (err u105))
(define-constant ERR_INVALID_EXPIRY (err u106))
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u107))
(define-constant ERR_OPTION_NOT_EXERCISABLE (err u108))
(define-constant ERR_STALE_PRICE (err u109))
(define-constant ERR_INVALID_PRICE (err u110))
(define-constant ERR_OPTION_NOT_EXPIRED (err u111))
(define-constant ERR_INVALID_PARAMETER (err u112))

;; Data Variables

(define-data-var min-collateral-ratio uint u150) ;; 150% collateral ratio
(define-data-var platform-fee uint u10) ;; 0.1% fee (basis points)
(define-data-var next-option-id uint u0)

;; Oracle Variables
(define-data-var oracle-address principal CONTRACT_OWNER)
(define-data-var btc-price uint u0)
(define-data-var price-last-updated uint u0)
(define-data-var price-validity-window uint u150) ;; ~25 minutes in blocks

;; Data Maps

;; Options Storage
(define-map options
    uint ;; option-id
    {
        creator: principal,
        holder: principal,
        option-type: (string-ascii 4), ;; "CALL" or "PUT"
        strike-price: uint,
        expiry: uint,
        amount: uint,
        collateral: uint,
        status: (string-ascii 10) ;; "ACTIVE", "EXERCISED", "EXPIRED"
    }
)

;; User Balances
(define-map user-balances
    principal
    {
        sbtc-balance: uint,
        locked-collateral: uint
    }
)

;; Oracle Functions

;; Update BTC Price
(define-public (update-btc-price (new-price uint))
    (begin
        (asserts! (is-eq tx-sender (var-get oracle-address)) ERR_NOT_AUTHORIZED)
        (asserts! (> new-price u0) ERR_INVALID_PRICE)
        (var-set btc-price new-price)
        (var-set price-last-updated block-height)
        (ok true))
)

;; Get Current BTC Price
(define-read-only (get-current-btc-price)
    (let (
        (price (var-get btc-price))
        (last-updated (var-get price-last-updated))
        (validity-window (var-get price-validity-window))
    )
    (asserts! (> price u0) ERR_INVALID_PRICE)
    (asserts! (< (- block-height last-updated) validity-window) ERR_STALE_PRICE)
    (ok price))
)

;; Set Oracle Address
(define-public (set-oracle-address (new-oracle principal))
    (begin
        (asserts! (is-contract-owner) ERR_NOT_AUTHORIZED)
        ;; Check that new oracle address is not null/zero address
        (asserts! (not (is-eq new-oracle 'SP000000000000000000002Q6VF78)) ERR_INVALID_PARAMETER)
        (var-set oracle-address new-oracle)
        (ok true))
)

;; Set Price Validity Window
(define-public (set-price-validity-window (new-window uint))
    (begin
        (asserts! (is-contract-owner) ERR_NOT_AUTHORIZED)
        (asserts! (and (>= new-window MIN_VALIDITY_WINDOW) 
                      (<= new-window MAX_VALIDITY_WINDOW)) ERR_INVALID_PARAMETER)
        (var-set price-validity-window new-window)
        (ok true))
)

;; Private Functions

;; Authorization Check
(define-private (is-contract-owner)
    (is-eq tx-sender CONTRACT_OWNER)
)

;; Option Expiry Check
(define-private (check-expiry (option-id uint))
    (let (
        (option (unwrap! (map-get? options option-id) ERR_OPTION_NOT_FOUND))
        (current-height block-height)
    )
    (if (> current-height (get expiry option))
        ERR_OPTION_EXPIRED
        (ok true)
    ))
)

;; Balance Management
(define-private (update-user-balance (user principal) (delta uint) (is-subtract bool))
    (let (
        (current-balance (default-to {sbtc-balance: u0, locked-collateral: u0} 
                        (map-get? user-balances user)))
        (current-sbtc (get sbtc-balance current-balance))
        (new-balance (if is-subtract
                        (begin
                            (asserts! (>= current-sbtc delta) ERR_INSUFFICIENT_BALANCE)
                            (- current-sbtc delta))
                        (+ current-sbtc delta)))
    )
    (ok (map-set user-balances 
        user 
        (merge current-balance {sbtc-balance: new-balance})))
    )
)