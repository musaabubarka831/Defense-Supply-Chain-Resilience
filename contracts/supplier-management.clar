;; title: supplier-management
;; Alternative Supplier Development and Qualification Smart Contract
;; Manages supplier registration, qualification tracking, and performance monitoring

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-INVALID-QUALIFICATION (err u103))
(define-constant ERR-INVALID-PERFORMANCE (err u104))
(define-constant ERR-SUPPLIER-INACTIVE (err u105))
(define-constant ERR-INSUFFICIENT-PERMISSION (err u106))

;; Qualification levels
(define-constant QUALIFICATION-PENDING u0)
(define-constant QUALIFICATION-BASIC u1)
(define-constant QUALIFICATION-STANDARD u2)
(define-constant QUALIFICATION-ADVANCED u3)
(define-constant QUALIFICATION-CRITICAL u4)

;; Data Variables
(define-data-var total-suppliers uint u0)
(define-data-var emergency-mode bool false)

;; Data Maps
(define-map suppliers
  { supplier-id: (string-ascii 50) }
  {
    name: (string-ascii 100),
    category: (string-ascii 50),
    qualification-level: uint,
    performance-score: uint,
    registration-date: uint,
    last-updated: uint,
    active: bool,
    emergency-qualified: bool,
    contact-info: (string-ascii 200),
    certifications: (list 10 (string-ascii 50))
  }
)

(define-map supplier-performance
  { supplier-id: (string-ascii 50), metric-id: uint }
  {
    delivery-time: uint,
    quality-rating: uint,
    cost-effectiveness: uint,
    compliance-score: uint,
    recorded-at: uint,
    recorded-by: principal
  }
)

(define-map supplier-authorizations
  { supplier-id: (string-ascii 50) }
  { authorized-users: (list 20 principal) }
)

(define-map qualification-history
  { supplier-id: (string-ascii 50), timestamp: uint }
  {
    previous-level: uint,
    new-level: uint,
    reason: (string-ascii 200),
    approved-by: principal
  }
)

;; Public Functions

;; Register a new supplier
(define-public (register-supplier 
    (supplier-id (string-ascii 50))
    (name (string-ascii 100))
    (category (string-ascii 50))
    (initial-qualification uint)
    (contact-info (string-ascii 200))
    (certifications (list 10 (string-ascii 50)))
  )
  (begin
    ;; Check if supplier already exists
    (asserts! (is-none (map-get? suppliers { supplier-id: supplier-id })) ERR-ALREADY-EXISTS)
    ;; Validate qualification level
    (asserts! (<= initial-qualification QUALIFICATION-CRITICAL) ERR-INVALID-QUALIFICATION)
    
    ;; Register the supplier
    (map-set suppliers
      { supplier-id: supplier-id }
      {
        name: name,
        category: category,
        qualification-level: initial-qualification,
        performance-score: u50, ;; Default starting score
        registration-date: block-height,
        last-updated: block-height,
        active: true,
        emergency-qualified: false,
        contact-info: contact-info,
        certifications: certifications
      }
    )
    
    ;; Increment total suppliers
    (var-set total-suppliers (+ (var-get total-suppliers) u1))
    
    ;; Log qualification history
    (map-set qualification-history
      { supplier-id: supplier-id, timestamp: block-height }
      {
        previous-level: u0,
        new-level: initial-qualification,
        reason: "Initial registration",
        approved-by: tx-sender
      }
    )
    
    (ok supplier-id)
  )
)

;; Update supplier qualification level
(define-public (update-qualification
    (supplier-id (string-ascii 50))
    (new-level uint)
    (reason (string-ascii 200))
  )
  (let (
    (supplier (unwrap! (map-get? suppliers { supplier-id: supplier-id }) ERR-NOT-FOUND))
    (current-level (get qualification-level supplier))
  )
    ;; Validate qualification level
    (asserts! (<= new-level QUALIFICATION-CRITICAL) ERR-INVALID-QUALIFICATION)
    
    ;; Update supplier qualification
    (map-set suppliers
      { supplier-id: supplier-id }
      (merge supplier {
        qualification-level: new-level,
        last-updated: block-height
      })
    )
    
    ;; Record qualification history
    (map-set qualification-history
      { supplier-id: supplier-id, timestamp: block-height }
      {
        previous-level: current-level,
        new-level: new-level,
        reason: reason,
        approved-by: tx-sender
      }
    )
    
    (ok new-level)
  )
)

;; Record supplier performance metrics
(define-public (record-performance
    (supplier-id (string-ascii 50))
    (metric-id uint)
    (delivery-time uint)
    (quality-rating uint)
    (cost-effectiveness uint)
    (compliance-score uint)
  )
  (let (
    (supplier (unwrap! (map-get? suppliers { supplier-id: supplier-id }) ERR-NOT-FOUND))
  )
    ;; Validate performance scores (0-100)
    (asserts! (<= quality-rating u100) ERR-INVALID-PERFORMANCE)
    (asserts! (<= cost-effectiveness u100) ERR-INVALID-PERFORMANCE)
    (asserts! (<= compliance-score u100) ERR-INVALID-PERFORMANCE)
    
    ;; Record performance metrics
    (map-set supplier-performance
      { supplier-id: supplier-id, metric-id: metric-id }
      {
        delivery-time: delivery-time,
        quality-rating: quality-rating,
        cost-effectiveness: cost-effectiveness,
        compliance-score: compliance-score,
        recorded-at: block-height,
        recorded-by: tx-sender
      }
    )
    
    ;; Calculate and update overall performance score
    (let (
      (overall-score (/ (+ quality-rating cost-effectiveness compliance-score) u3))
    )
      (map-set suppliers
        { supplier-id: supplier-id }
        (merge supplier {
          performance-score: overall-score,
          last-updated: block-height
        })
      )
      (ok overall-score)
    )
  )
)

;; Activate emergency supplier status
(define-public (activate-emergency-supplier
    (supplier-id (string-ascii 50))
    (reason (string-ascii 200))
  )
  (let (
    (supplier (unwrap! (map-get? suppliers { supplier-id: supplier-id }) ERR-NOT-FOUND))
  )
    ;; Only contract owner or emergency mode can activate
    (asserts! (or (is-eq tx-sender CONTRACT-OWNER) (var-get emergency-mode)) ERR-INSUFFICIENT-PERMISSION)
    
    ;; Update supplier emergency status
    (map-set suppliers
      { supplier-id: supplier-id }
      (merge supplier {
        emergency-qualified: true,
        last-updated: block-height
      })
    )
    
    ;; Record in qualification history
    (map-set qualification-history
      { supplier-id: supplier-id, timestamp: block-height }
      {
        previous-level: (get qualification-level supplier),
        new-level: (get qualification-level supplier),
        reason: "Emergency supplier activation",
        approved-by: tx-sender
      }
    )
    
    (ok true)
  )
)

;; Deactivate supplier
(define-public (deactivate-supplier
    (supplier-id (string-ascii 50))
    (reason (string-ascii 200))
  )
  (let (
    (supplier (unwrap! (map-get? suppliers { supplier-id: supplier-id }) ERR-NOT-FOUND))
  )
    ;; Only contract owner can deactivate
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    
    ;; Update supplier status
    (map-set suppliers
      { supplier-id: supplier-id }
      (merge supplier {
        active: false,
        emergency-qualified: false,
        last-updated: block-height
      })
    )
    
    ;; Record deactivation in history
    (map-set qualification-history
      { supplier-id: supplier-id, timestamp: block-height }
      {
        previous-level: (get qualification-level supplier),
        new-level: u0,
        reason: "Supplier deactivated",
        approved-by: tx-sender
      }
    )
    
    (ok true)
  )
)

;; Set emergency mode (only contract owner)
(define-public (set-emergency-mode (enabled bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (var-set emergency-mode enabled)
    (ok enabled)
  )
)

;; Read-Only Functions

;; Get supplier information
(define-read-only (get-supplier-info (supplier-id (string-ascii 50)))
  (map-get? suppliers { supplier-id: supplier-id })
)

;; Get supplier performance metrics
(define-read-only (get-performance-metrics 
    (supplier-id (string-ascii 50))
    (metric-id uint)
  )
  (map-get? supplier-performance { supplier-id: supplier-id, metric-id: metric-id })
)

;; Get qualification history
(define-read-only (get-qualification-history
    (supplier-id (string-ascii 50))
    (timestamp uint)
  )
  (map-get? qualification-history { supplier-id: supplier-id, timestamp: timestamp })
)

;; Check if supplier is active and qualified
(define-read-only (is-supplier-qualified
    (supplier-id (string-ascii 50))
    (minimum-qualification uint)
  )
  (match (map-get? suppliers { supplier-id: supplier-id })
    supplier (
      and
        (get active supplier)
        (>= (get qualification-level supplier) minimum-qualification)
    )
    false
  )
)

;; Get total number of suppliers
(define-read-only (get-total-suppliers)
  (var-get total-suppliers)
)

;; Check if emergency mode is enabled
(define-read-only (is-emergency-mode)
  (var-get emergency-mode)
)

;; Get contract owner
(define-read-only (get-contract-owner)
  CONTRACT-OWNER
)

