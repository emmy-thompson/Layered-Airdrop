;; Token Airdrop Distribution Contract Smart Contract
;; 
;; This smart contract enables secure and controlled distribution of fungible tokens
;; to eligible recipients through a whitelist-based airdrop system. The contract features
;; a multi-tier reward structure, administrative controls for pausing/resuming distributions,
;; batch processing capabilities, and automatic recovery of unclaimed tokens after a lockup period.
;; All actions are logged for comprehensive audit trails and transparency.

;; Define the fungible token used for airdrop rewards
(define-fungible-token reward-token u1000000000)

;; Store the principal address of the contract owner/administrator
(define-data-var contract-owner principal tx-sender)

;; Define the four reward tier levels for recipients
(define-constant tier-bronze u1)
(define-constant tier-silver u2)
(define-constant tier-gold u3)
(define-constant tier-platinum u4)

;; Error codes for various validation and operational failures
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-DUPLICATE-CLAIM-ATTEMPT (err u101))
(define-constant ERR-RECIPIENT-NOT-ELIGIBLE (err u102))
(define-constant ERR-INSUFFICIENT-TOKEN-BALANCE (err u103))
(define-constant ERR-DISTRIBUTION-CURRENTLY-PAUSED (err u104))
(define-constant ERR-INVALID-REWARD-AMOUNT (err u105))
(define-constant ERR-PREMATURE-RECLAIM-ATTEMPT (err u106))
(define-constant ERR-RECIPIENT-ALREADY-WHITELISTED (err u107))
(define-constant ERR-INVALID-TIME-PERIOD (err u108))
(define-constant ERR-MATHEMATICAL-OVERFLOW-DETECTED (err u109))
(define-constant ERR-ZERO-AMOUNT-PROVIDED (err u110))
(define-constant ERR-TOKEN-MINTING-FAILURE (err u111))
(define-constant ERR-INVALID-PRINCIPAL-ADDRESS (err u112))
(define-constant ERR-INVALID-TIER-LEVEL (err u113))
(define-constant ERR-TIER-ALREADY-SET (err u114))

;; Track whether token distribution is currently active or paused
(define-data-var distribution-active bool true)

;; Cumulative count of all tokens distributed through claims
(define-data-var total-distributed-tokens uint u0)

;; Default reward amount when tier system is disabled
(define-data-var base-reward-amount uint u100)

;; Block height when contract was deployed (used for lockup calculations)
(define-data-var deployment-block uint block-height)

;; Number of blocks tokens remain locked before admin can reclaim
(define-data-var reclaim-lockup-blocks uint u10000)

;; Reward amounts for each tier level
(define-data-var bronze-reward uint u100)
(define-data-var silver-reward uint u250)
(define-data-var gold-reward uint u500)
(define-data-var platinum-reward uint u1000)

;; Flag to enable or disable the multi-tier reward system
(define-data-var tier-system-active bool false)

;; Map tracking which principals are eligible to claim tokens
(define-map whitelist-registry principal bool)

;; Map recording the amount claimed by each recipient
(define-map claim-history principal uint)

;; Map storing the tier assignment for each recipient
(define-map tier-assignments principal uint)

;; Counter for total number of events logged
(define-data-var event-log-counter uint u0)

;; Map storing event details for audit trail
(define-map event-log uint {action-type: (string-ascii 25), event-details: (string-ascii 256)})

;; Safely add two unsigned integers with overflow protection
;; Returns u0 if overflow would occur, otherwise returns the sum
(define-private (safe-add (operand-a uint) (operand-b uint))
  (let ((sum (+ operand-a operand-b)))
    (if (>= sum operand-a) 
        sum
        (begin
          (print "Overflow prevented in addition operation")
          u0))))

;; Record an event to the contract's audit log
;; Returns the event ID for the newly created log entry
(define-private (log-event (action-type (string-ascii 25)) (event-details (string-ascii 256)))
  (let ((event-id (var-get event-log-counter)))
    (map-set event-log event-id {action-type: action-type, event-details: event-details})
    (var-set event-log-counter (+ event-id u1))
    event-id))

;; Check if the transaction sender is the contract owner
;; Returns true if sender is owner, false otherwise
(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner)))

;; Validate that a principal address is legitimate and not a system address
;; Returns true if valid, false if contract address or burn address
(define-private (validate-principal (address principal))
  (and 
    (not (is-eq address (as-contract tx-sender)))
    (not (is-eq address 'SP000000000000000000002Q6VF78))))

;; Check if a tier level is within valid range (1-4)
;; Returns true if valid, false otherwise
(define-private (validate-tier (tier uint))
  (and 
    (>= tier tier-bronze)
    (<= tier tier-platinum)))

;; Calculate the reward amount based on recipient's tier level
;; Returns the appropriate reward amount for the given tier
(define-private (calculate-reward-for-tier (tier uint))
  (if (var-get tier-system-active)
    (if (is-eq tier tier-bronze)
        (var-get bronze-reward)
        (if (is-eq tier tier-silver)
            (var-get silver-reward)
            (if (is-eq tier tier-gold)
                (var-get gold-reward)
                (if (is-eq tier tier-platinum)
                    (var-get platinum-reward)
                    (var-get base-reward-amount)))))
    (var-get base-reward-amount)))

;; Transfer ownership of the contract to a new administrator
;; Only current owner can execute this function
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (validate-principal new-owner) ERR-INVALID-PRINCIPAL-ADDRESS)
    (asserts! (not (is-eq new-owner (var-get contract-owner))) ERR-INVALID-PRINCIPAL-ADDRESS)
    (var-set contract-owner new-owner)
    (log-event "ownership-transfer" "Contract ownership transferred to new administrator")
    (ok true)))

;; Toggle the distribution state between active and paused
;; Only owner can execute this function
(define-public (pause-or-resume-distribution)
  (begin
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED-ACCESS)
    (let ((new-status (not (var-get distribution-active))))
      (var-set distribution-active new-status)
      (log-event "distribution-toggle" (if new-status "Distribution resumed" "Distribution paused"))
      (ok new-status))))

;; Enable or disable the multi-tier reward system
;; Only owner can execute this function
(define-public (activate-or-deactivate-tiers)
  (begin
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED-ACCESS)
    (let ((new-status (not (var-get tier-system-active))))
      (var-set tier-system-active new-status)
      (log-event "tier-system-toggle" (if new-status "Multi-tier system enabled" "Multi-tier system disabled"))
      (ok new-status))))

;; Set the reward amounts for all four tier levels
;; All amounts must be greater than zero
(define-public (set-tier-rewards (bronze uint) (silver uint) (gold uint) (platinum uint))
  (begin
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (> bronze u0) ERR-INVALID-REWARD-AMOUNT)
    (asserts! (> silver u0) ERR-INVALID-REWARD-AMOUNT)
    (asserts! (> gold u0) ERR-INVALID-REWARD-AMOUNT)
    (asserts! (> platinum u0) ERR-INVALID-REWARD-AMOUNT)
    (var-set bronze-reward bronze)
    (var-set silver-reward silver)
    (var-set gold-reward gold)
    (var-set platinum-reward platinum)
    (log-event "tier-rewards-updated" "All tier reward amounts configured")
    (ok true)))

;; Add a single recipient to the whitelist without tier assignment
;; Only owner can execute this function
(define-public (add-recipient (recipient principal))
  (begin
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (validate-principal recipient) ERR-INVALID-PRINCIPAL-ADDRESS)
    (asserts! (is-none (map-get? whitelist-registry recipient)) ERR-RECIPIENT-ALREADY-WHITELISTED)
    (map-set whitelist-registry recipient true)
    (log-event "recipient-added" "New recipient added to whitelist")
    (ok true)))

;; Add a recipient to the whitelist with a specific tier assignment
;; Only owner can execute this function
(define-public (add-recipient-with-tier (recipient principal) (tier uint))
  (begin
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (validate-principal recipient) ERR-INVALID-PRINCIPAL-ADDRESS)
    (asserts! (validate-tier tier) ERR-INVALID-TIER-LEVEL)
    (asserts! (is-none (map-get? whitelist-registry recipient)) ERR-RECIPIENT-ALREADY-WHITELISTED)
    (map-set whitelist-registry recipient true)
    (map-set tier-assignments recipient tier)
    (log-event "tiered-recipient-added" "Recipient added with tier assignment")
    (ok true)))

;; Change the tier level of an existing whitelisted recipient
;; Recipient must not have already claimed tokens
(define-public (modify-recipient-tier (recipient principal) (new-tier uint))
  (begin
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (validate-principal recipient) ERR-INVALID-PRINCIPAL-ADDRESS)
    (asserts! (validate-tier new-tier) ERR-INVALID-TIER-LEVEL)
    (asserts! (is-some (map-get? whitelist-registry recipient)) ERR-RECIPIENT-NOT-ELIGIBLE)
    (asserts! (is-none (map-get? claim-history recipient)) ERR-DUPLICATE-CLAIM-ATTEMPT)
    (map-set tier-assignments recipient new-tier)
    (log-event "tier-modified" "Recipient tier level updated")
    (ok true)))

;; Add multiple recipients with tier assignments in a single transaction
;; Accepts up to 25 recipients at once
(define-public (batch-add-with-tiers (recipient-list (list 25 {recipient: principal, tier: uint})))
  (begin
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED-ACCESS)
    (log-event "batch-tier-add" "Batch registration with tiers completed")
    (ok (map add-single-recipient-with-tier recipient-list))))

;; Helper function to process individual recipient-tier pairs in batch operations
;; Validates and adds recipient with tier if all conditions are met
(define-private (add-single-recipient-with-tier (data {recipient: principal, tier: uint}))
  (let (
    (recipient (get recipient data))
    (tier (get tier data))
  )
    (if (and 
          (validate-principal recipient)
          (validate-tier tier)
          (not (default-to false (map-get? whitelist-registry recipient))))
        (begin
          (map-set whitelist-registry recipient true)
          (map-set tier-assignments recipient tier)
          true)
        false)))

;; Remove a recipient from the whitelist and clear their tier assignment
;; Only owner can execute this function
(define-public (remove-recipient (recipient principal))
  (begin
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (validate-principal recipient) ERR-INVALID-PRINCIPAL-ADDRESS)
    (asserts! (is-some (map-get? whitelist-registry recipient)) ERR-RECIPIENT-NOT-ELIGIBLE)
    (map-delete whitelist-registry recipient)
    (map-delete tier-assignments recipient)
    (log-event "recipient-removed" "Recipient removed from whitelist")
    (ok true)))

;; Add multiple recipients to the whitelist in a single transaction
;; Accepts up to 50 recipients at once
(define-public (batch-add-recipients (recipients (list 50 principal)))
  (begin
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED-ACCESS)
    (log-event "batch-add" "Multiple recipients added via batch operation")
    (ok (map add-single-recipient recipients))))

;; Helper function to add a single recipient during batch operations
;; Validates and adds recipient if not already whitelisted
(define-private (add-single-recipient (recipient principal))
  (begin
    (if (and 
          (validate-principal recipient)
          (not (default-to false (map-get? whitelist-registry recipient))))
        (map-set whitelist-registry recipient true)
        false)
    true))

;; Update the base reward amount for non-tiered distributions
;; Amount must be greater than zero
(define-public (set-base-reward (new-amount uint))
  (begin
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (> new-amount u0) ERR-INVALID-REWARD-AMOUNT)
    (var-set base-reward-amount new-amount)
    (log-event "reward-updated" "Base reward amount changed")
    (ok new-amount)))

;; Configure the lockup period in blocks before unclaimed tokens can be reclaimed
;; Period must be greater than zero
(define-public (set-lockup-period (blocks uint))
  (begin
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (> blocks u0) ERR-INVALID-TIME-PERIOD)
    (var-set reclaim-lockup-blocks blocks)
    (log-event "lockup-updated" "Token lockup period modified")
    (ok blocks)))

;; Allow eligible recipients to claim their airdrop tokens
;; Calculates reward based on tier assignment and transfers tokens
(define-public (claim-tokens)
  (let (
    (claimer tx-sender)
    (assigned-tier (default-to tier-bronze (map-get? tier-assignments claimer)))
    (reward-amount (calculate-reward-for-tier assigned-tier))
  )
    (asserts! (var-get distribution-active) ERR-DISTRIBUTION-CURRENTLY-PAUSED)
    (asserts! (is-some (map-get? whitelist-registry claimer)) ERR-RECIPIENT-NOT-ELIGIBLE)
    (asserts! (is-none (map-get? claim-history claimer)) ERR-DUPLICATE-CLAIM-ATTEMPT)
    (asserts! (<= reward-amount (ft-get-balance reward-token (var-get contract-owner))) ERR-INSUFFICIENT-TOKEN-BALANCE)
    
    (match (ft-transfer? reward-token reward-amount (var-get contract-owner) claimer)
      success (begin
        (map-set claim-history claimer reward-amount)
        (let ((new-total (safe-add (var-get total-distributed-tokens) reward-amount)))
          (asserts! (> new-total u0) ERR-MATHEMATICAL-OVERFLOW-DETECTED)
          (var-set total-distributed-tokens new-total)
          (log-event "tokens-claimed" "Recipient successfully claimed airdrop tokens")
          (ok reward-amount)))
      error (err error))))

;; Allow owner to reclaim unclaimed tokens after lockup period expires
;; Transfers all remaining tokens from owner to specified destination
(define-public (reclaim-unclaimed-tokens (destination principal))
  (let (
    (current-block block-height)
    (unlock-block (+ (var-get deployment-block) (var-get reclaim-lockup-blocks)))
  )
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (validate-principal destination) ERR-INVALID-PRINCIPAL-ADDRESS)
    (asserts! (not (is-eq destination (var-get contract-owner))) ERR-INVALID-PRINCIPAL-ADDRESS)
    (asserts! (>= current-block unlock-block) ERR-PREMATURE-RECLAIM-ATTEMPT)
    
    (let (
      (remaining-balance (ft-get-balance reward-token (var-get contract-owner)))
    )
      (asserts! (> remaining-balance u0) ERR-ZERO-AMOUNT-PROVIDED)
      (match (ft-transfer? reward-token remaining-balance (var-get contract-owner) destination)
        success (begin
          (log-event "tokens-reclaimed" "Unclaimed tokens reclaimed by administrator")
          (ok remaining-balance))
        error (err error)))))

;; Get the current contract owner address
(define-read-only (get-owner)
  (var-get contract-owner))

;; Check if distribution is currently active
(define-read-only (is-distribution-active)
  (var-get distribution-active))

;; Check if the tier system is currently enabled
(define-read-only (is-tier-system-active)
  (var-get tier-system-active))

;; Get reward amounts for all tier levels
(define-read-only (get-all-tier-rewards)
  {
    bronze: (var-get bronze-reward),
    silver: (var-get silver-reward),
    gold: (var-get gold-reward),
    platinum: (var-get platinum-reward)
  })

;; Get the tier assignment for a specific recipient
(define-read-only (get-tier (recipient principal))
  (default-to tier-bronze (map-get? tier-assignments recipient)))

;; Calculate potential reward for a recipient based on their tier
(define-read-only (get-potential-reward (recipient principal))
  (let ((tier (default-to tier-bronze (map-get? tier-assignments recipient))))
    (calculate-reward-for-tier tier)))

;; Check if a recipient is whitelisted
(define-read-only (is-whitelisted (recipient principal))
  (default-to false (map-get? whitelist-registry recipient)))

;; Check if a recipient has already claimed tokens
(define-read-only (has-claimed (recipient principal))
  (is-some (map-get? claim-history recipient)))

;; Get the amount of tokens claimed by a specific recipient
(define-read-only (get-claimed-amount (recipient principal))
  (default-to u0 (map-get? claim-history recipient)))

;; Get the total amount of tokens distributed through all claims
(define-read-only (get-total-distributed)
  (var-get total-distributed-tokens))

;; Get the current base reward amount
(define-read-only (get-base-reward)
  (var-get base-reward-amount))

;; Get the configured lockup period in blocks
(define-read-only (get-lockup-period)
  (var-get reclaim-lockup-blocks))

;; Get the block height when the contract was deployed
(define-read-only (get-deployment-block)
  (var-get deployment-block))

;; Retrieve event log details by event ID
(define-read-only (get-event (event-id uint))
  (map-get? event-log event-id))

;; Initialize the contract by minting initial token supply
;; Called automatically during contract deployment
(define-private (initialize-contract)
  (begin
    (match (ft-mint? reward-token u1000000000 tx-sender)
      success (begin
        (log-event "contract-initialized" "Airdrop contract deployed and initialized")
        true)
      error false)))

;; Execute initialization on deployment
(initialize-contract)