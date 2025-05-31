;; Constants
(define-constant ECO_IMPACT_CAPACITY u2500000)
(define-constant BASE_ACTION_REWARD u18)
(define-constant SUSTAINABILITY_BONUS u6)
(define-constant MAX_SUSTAINABILITY_LEVEL u9)
(define-constant ERR_INVALID_ECO_ACTION u1)
(define-constant ERR_NO_ECO_TOKENS u2)
(define-constant ERR_IMPACT_EXCEEDED u3)
(define-constant BLOCKS_PER_ECO_CYCLE u2016)
(define-constant CONSERVATION_MULTIPLIER u3)
(define-constant MIN_CONSERVATION_DURATION u1008)
(define-constant EARLY_RELEASE_PENALTY u18)

;; Data Variables
(define-data-var total-eco-tokens-issued uint u0)
(define-data-var total-eco-actions uint u0)
(define-data-var environmental-coordinator principal tx-sender)

;; Data Maps
(define-map activist-actions principal uint)
(define-map activist-eco-tokens principal uint)
(define-map eco-action-start-time principal uint)
(define-map activist-sustainability principal uint)
(define-map activist-last-action principal uint)
(define-map activist-conserved-tokens principal uint)
(define-map activist-conservation-start-block principal uint)

;; Public Functions

(define-public (start-eco-action (impact uint))
  (let
    (
      (activist tx-sender)
    )
    (asserts! (> impact u0) (err ERR_INVALID_ECO_ACTION))
    (map-set eco-action-start-time activist burn-block-height)
    (ok true)
  )
)

(define-public (complete-eco-action (impact uint))
  (let
    (
      (activist tx-sender)
      (start-block (default-to u0 (map-get? eco-action-start-time activist)))
      (blocks-active (- burn-block-height start-block))
      (last-action-block (default-to u0 (map-get? activist-last-action activist)))
      (sustainability-level (default-to u0 (map-get? activist-sustainability activist)))
      (capped-sustainability (if (<= sustainability-level MAX_SUSTAINABILITY_LEVEL) sustainability-level MAX_SUSTAINABILITY_LEVEL))
      (reward-amount (+ BASE_ACTION_REWARD (* capped-sustainability SUSTAINABILITY_BONUS)))
    )
    (asserts! (and (> start-block u0) (>= blocks-active impact)) (err ERR_INVALID_ECO_ACTION))
    (map-set activist-actions activist (+ (default-to u0 (map-get? activist-actions activist)) u1))
    (map-set activist-eco-tokens activist (+ (default-to u0 (map-get? activist-eco-tokens activist)) reward-amount))
    (if (< (- burn-block-height last-action-block) BLOCKS_PER_ECO_CYCLE)
      (map-set activist-sustainability activist (+ sustainability-level u1))
      (map-set activist-sustainability activist u1)
    )
    (map-set activist-last-action activist burn-block-height)
    (var-set total-eco-actions (+ (var-get total-eco-actions) u1))
    (var-set total-eco-tokens-issued (+ (var-get total-eco-tokens-issued) reward-amount))
    (asserts! (<= (var-get total-eco-tokens-issued) ECO_IMPACT_CAPACITY) (err ERR_IMPACT_EXCEEDED))
    (ok reward-amount)
  )
)

(define-public (claim-eco-rewards)
  (let
    (
      (activist tx-sender)
      (token-balance (default-to u0 (map-get? activist-eco-tokens activist)))
    )
    (asserts! (> token-balance u0) (err ERR_NO_ECO_TOKENS))
    (map-set activist-eco-tokens activist u0)
    (ok token-balance)
  )
)

;; Conservation Features

(define-public (conserve-eco-tokens (amount uint))
  (let
    (
      (activist tx-sender)
    )
    (asserts! (> amount u0) (err ERR_INVALID_ECO_ACTION))
    (asserts! (>= (var-get total-eco-tokens-issued) amount) (err ERR_IMPACT_EXCEEDED))
    (map-set activist-conserved-tokens activist amount)
    (map-set activist-conservation-start-block activist burn-block-height)
    (var-set total-eco-tokens-issued (- (var-get total-eco-tokens-issued) amount))
    (ok amount)
  )
)

(define-public (release-conserved-tokens)
  (let
    (
      (activist tx-sender)
      (conserved-amount (default-to u0 (map-get? activist-conserved-tokens activist)))
      (conservation-start-block (default-to u0 (map-get? activist-conservation-start-block activist)))
      (blocks-conserved (- burn-block-height conservation-start-block))
      (penalty (if (< blocks-conserved MIN_CONSERVATION_DURATION) (/ (* conserved-amount EARLY_RELEASE_PENALTY) u100) u0))
      (final-amount (- conserved-amount penalty))
    )
    (asserts! (> conserved-amount u0) (err ERR_NO_ECO_TOKENS))
    (map-set activist-conserved-tokens activist u0)
    (map-set activist-conservation-start-block activist u0)
    (var-set total-eco-tokens-issued (+ (var-get total-eco-tokens-issued) final-amount))
    (ok final-amount)
  )
)

;; Read-Only Functions

(define-read-only (get-eco-action-count (user principal))
  (default-to u0 (map-get? activist-actions user))
)

(define-read-only (get-eco-token-balance (user principal))
  (default-to u0 (map-get? activist-eco-tokens user))
)

(define-read-only (get-sustainability-level (user principal))
  (default-to u0 (map-get? activist-sustainability user))
)

(define-read-only (get-eco-impact-stats)
  {
    total-eco-actions: (var-get total-eco-actions),
    total-eco-tokens-issued: (var-get total-eco-tokens-issued)
  }
)

;; Private Functions

(define-private (is-environmental-coordinator)
  (is-eq tx-sender (var-get environmental-coordinator))
)