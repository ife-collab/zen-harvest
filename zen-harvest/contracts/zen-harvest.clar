;; ZenHarvest - Decentralized Autonomous Scheduling Infrastructure
;; A simplified implementation for Stacks blockchain

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-insufficient-stake (err u103))
(define-constant err-task-already-exists (err u104))
(define-constant err-task-not-ready (err u105))
(define-constant err-invalid-block-height (err u106))
(define-constant err-task-already-executed (err u107))

;; Minimum stake required per task (in microSTX)
(define-constant min-stake-amount u1000000) ;; 1 STX

;; Data Variables
(define-data-var task-counter uint u0)
(define-data-var total-staked uint u0)

;; Data Maps
;; Task structure: stores scheduled tasks
(define-map tasks
    { task-id: uint }
    {
        creator: principal,
        executor: (optional principal),
        target-block: uint,
        stake-amount: uint,
        executed: bool,
        callback-contract: (optional principal),
        task-data: (string-utf8 256)
    }
)

;; Validator stakes
(define-map validator-stakes
    { validator: principal }
    { total-stake: uint, active-tasks: uint, reputation-score: uint }
)

;; Task assignments
(define-map task-assignments
    { task-id: uint }
    { validator: principal, assigned-at: uint }
)

;; Read-only functions

;; Get task details
(define-read-only (get-task (task-id uint))
    (map-get? tasks { task-id: task-id })
)

;; Get validator stake info
(define-read-only (get-validator-stake (validator principal))
    (map-get? validator-stakes { validator: validator })
)

;; Get task assignment
(define-read-only (get-task-assignment (task-id uint))
    (map-get? task-assignments { task-id: task-id })
)

;; Get current task counter
(define-read-only (get-task-counter)
    (ok (var-get task-counter))
)

;; Get total staked amount
(define-read-only (get-total-staked)
    (ok (var-get total-staked))
)

;; Check if task is ready for execution
(define-read-only (is-task-ready (task-id uint))
    (match (get-task task-id)
        task-info (ok (>= block-height (get target-block task-info)))
        (err err-not-found)
    )
)

;; Public functions

;; Create a scheduled task
(define-public (create-task (target-block uint) (task-data (string-utf8 256)) (stake-amount uint))
    (let
        (
            (task-id (+ (var-get task-counter) u1))
            (current-block block-height)
        )
        ;; Validations
        (asserts! (>= stake-amount min-stake-amount) err-insufficient-stake)
        (asserts! (> target-block current-block) err-invalid-block-height)
        
        ;; Transfer stake to contract
        (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
        
        ;; Create task
        (map-set tasks
            { task-id: task-id }
            {
                creator: tx-sender,
                executor: none,
                target-block: target-block,
                stake-amount: stake-amount,
                executed: false,
                callback-contract: none,
                task-data: task-data
            }
        )
        
        ;; Update counters
        (var-set task-counter task-id)
        (var-set total-staked (+ (var-get total-staked) stake-amount))
        
        (ok task-id)
    )
)

;; Validator stakes tokens to participate
(define-public (stake-as-validator (amount uint))
    (begin
        (asserts! (>= amount min-stake-amount) err-insufficient-stake)
        
        ;; Transfer stake to contract
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        ;; Update or create validator stake record
        (match (get-validator-stake tx-sender)
            existing-stake
                (map-set validator-stakes
                    { validator: tx-sender }
                    {
                        total-stake: (+ (get total-stake existing-stake) amount),
                        active-tasks: (get active-tasks existing-stake),
                        reputation-score: (get reputation-score existing-stake)
                    }
                )
            ;; New validator
            (map-set validator-stakes
                { validator: tx-sender }
                { total-stake: amount, active-tasks: u0, reputation-score: u100 }
            )
        )
        
        (var-set total-staked (+ (var-get total-staked) amount))
        (ok true)
    )
)

;; Assign a validator to a task
(define-public (assign-task (task-id uint) (validator principal))
    (let
        (
            (task-info (unwrap! (get-task task-id) err-not-found))
            (validator-info (unwrap! (get-validator-stake validator) err-not-found))
        )
        ;; Only task creator can assign
        (asserts! (is-eq tx-sender (get creator task-info)) err-unauthorized)
        
        ;; Check validator has sufficient stake
        (asserts! (>= (get total-stake validator-info) min-stake-amount) err-insufficient-stake)
        
        ;; Check task not already executed
        (asserts! (not (get executed task-info)) err-task-already-executed)
        
        ;; Create assignment
        (map-set task-assignments
            { task-id: task-id }
            { validator: validator, assigned-at: block-height }
        )
        
        ;; Update validator active tasks
        (map-set validator-stakes
            { validator: validator }
            (merge validator-info { active-tasks: (+ (get active-tasks validator-info) u1) })
        )
        
        (ok true)
    )
)

;; Execute a scheduled task
(define-public (execute-task (task-id uint))
    (let
        (
            (task-info (unwrap! (get-task task-id) err-not-found))
            (assignment (unwrap! (get-task-assignment task-id) err-not-found))
            (validator-info (unwrap! (get-validator-stake tx-sender) err-not-found))
        )
        ;; Validations
        (asserts! (is-eq tx-sender (get validator assignment)) err-unauthorized)
        (asserts! (not (get executed task-info)) err-task-already-executed)
        (asserts! (>= block-height (get target-block task-info)) err-task-not-ready)
        
        ;; Mark task as executed
        (map-set tasks
            { task-id: task-id }
            (merge task-info { executed: true, executor: (some tx-sender) })
        )
        
        ;; Calculate rewards (stake + 10% reward)
        (let
            (
                (reward (/ (* (get stake-amount task-info) u110) u100))
            )
            ;; Transfer reward to executor
            (try! (as-contract (stx-transfer? reward tx-sender (get validator assignment))))
            
            ;; Update validator stats
            (map-set validator-stakes
                { validator: tx-sender }
                {
                    total-stake: (get total-stake validator-info),
                    active-tasks: (- (get active-tasks validator-info) u1),
                    reputation-score: (+ (get reputation-score validator-info) u10)
                }
            )
            
            ;; Update total staked
            (var-set total-staked (- (var-get total-staked) (get stake-amount task-info)))
            
            (ok reward)
        )
    )
)

;; Withdraw validator stake
(define-public (withdraw-stake (amount uint))
    (let
        (
            (validator-info (unwrap! (get-validator-stake tx-sender) err-not-found))
        )
        ;; Check no active tasks
        (asserts! (is-eq (get active-tasks validator-info) u0) err-unauthorized)
        
        ;; Check sufficient balance
        (asserts! (<= amount (get total-stake validator-info)) err-insufficient-stake)
        
        ;; Transfer stake back
        (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
        
        ;; Update validator stake
        (map-set validator-stakes
            { validator: tx-sender }
            (merge validator-info { total-stake: (- (get total-stake validator-info) amount) })
        )
        
        (var-set total-staked (- (var-get total-staked) amount))
        (ok true)
    )
)

;; Cancel a task (only creator, before execution)
(define-public (cancel-task (task-id uint))
    (let
        (
            (task-info (unwrap! (get-task task-id) err-not-found))
        )
        ;; Only creator can cancel
        (asserts! (is-eq tx-sender (get creator task-info)) err-unauthorized)
        
        ;; Check not executed
        (asserts! (not (get executed task-info)) err-task-already-executed)
        
        ;; Refund stake
        (try! (as-contract (stx-transfer? (get stake-amount task-info) tx-sender (get creator task-info))))
        
        ;; Mark as executed (cancelled)
        (map-set tasks
            { task-id: task-id }
            (merge task-info { executed: true })
        )
        
        (var-set total-staked (- (var-get total-staked) (get stake-amount task-info)))
        (ok true)
    )
)

;; Initialize contract (constructor-like)
(begin
    (var-set task-counter u0)
    (var-set total-staked u0)
)
