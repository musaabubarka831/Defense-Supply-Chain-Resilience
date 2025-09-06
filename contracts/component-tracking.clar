;; title: component-tracking
;; Critical Component Identification and Tracking Smart Contract
;; Manages identification, tracking, and monitoring of critical supply chain components

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u200))
(define-constant ERR-NOT-FOUND (err u201))
(define-constant ERR-ALREADY-EXISTS (err u202))
(define-constant ERR-INVALID-CRITICALITY (err u203))
(define-constant ERR-INVALID-STATUS (err u204))
(define-constant ERR-UNAUTHORIZED-ACCESS (err u205))
(define-constant ERR-COMPONENT-COMPROMISED (err u206))

;; Criticality levels
(define-constant CRITICALITY-LOW u1)
(define-constant CRITICALITY-MEDIUM u2)
(define-constant CRITICALITY-HIGH u3)
(define-constant CRITICALITY-CRITICAL u4)
(define-constant CRITICALITY-TOP-SECRET u5)

;; Component status codes
(define-constant STATUS-PENDING u0)
(define-constant STATUS-VERIFIED u1)
(define-constant STATUS-IN-TRANSIT u2)
(define-constant STATUS-DELIVERED u3)
(define-constant STATUS-INSTALLED u4)
(define-constant STATUS-COMPROMISED u5)

;; Data Variables
(define-data-var total-components uint u0)
(define-data-var security-alert-level uint u0)
(define-data-var tracking-enabled bool true)

;; Data Maps
(define-map components
  { component-id: (string-ascii 50) }
  {
    name: (string-ascii 100),
    description: (string-ascii 200),
    criticality-level: uint,
    current-status: uint,
    supplier-id: (string-ascii 50),
    manufacturer: (string-ascii 100),
    serial-number: (string-ascii 50),
    creation-date: uint,
    last-updated: uint,
    authenticity-verified: bool,
    current-location: (string-ascii 100),
    destination: (string-ascii 100)
  }
)

(define-map component-history
  { component-id: (string-ascii 50), event-id: uint }
  {
    event-type: (string-ascii 50),
    location: (string-ascii 100),
    timestamp: uint,
    description: (string-ascii 200),
    recorded-by: principal,
    verification-hash: (string-ascii 64)
  }
)

(define-map component-access-log
  { component-id: (string-ascii 50), access-id: uint }
  {
    accessor: principal,
    access-type: (string-ascii 30),
    timestamp: uint,
    authorized: bool,
    access-reason: (string-ascii 100)
  }
)

(define-map risk-assessments
  { component-id: (string-ascii 50), assessment-id: uint }
  {
    risk-level: uint,
    risk-factors: (list 5 (string-ascii 50)),
    mitigation-actions: (string-ascii 200),
    assessed-by: principal,
    assessment-date: uint,
    validity-period: uint
  }
)

(define-map authorized-personnel
  { user: principal }
  {
    access-level: uint,
    department: (string-ascii 50),
    authorized-by: principal,
    authorization-date: uint,
    expiry-date: uint,
    active: bool
  }
)

;; Public Functions

;; Register a new critical component
(define-public (register-component
    (component-id (string-ascii 50))
    (name (string-ascii 100))
    (description (string-ascii 200))
    (criticality-level uint)
    (supplier-id (string-ascii 50))
    (manufacturer (string-ascii 100))
    (serial-number (string-ascii 50))
    (initial-location (string-ascii 100))
  )
  (begin
    ;; Check if component already exists
    (asserts! (is-none (map-get? components { component-id: component-id })) ERR-ALREADY-EXISTS)
    ;; Validate criticality level
    (asserts! (and (>= criticality-level CRITICALITY-LOW) (<= criticality-level CRITICALITY-TOP-SECRET)) ERR-INVALID-CRITICALITY)
    
    ;; Register the component
    (map-set components
      { component-id: component-id }
      {
        name: name,
        description: description,
        criticality-level: criticality-level,
        current-status: STATUS-PENDING,
        supplier-id: supplier-id,
        manufacturer: manufacturer,
        serial-number: serial-number,
        creation-date: block-height,
        last-updated: block-height,
        authenticity-verified: false,
        current-location: initial-location,
        destination: ""
      }
    )
    
    ;; Increment total components
    (var-set total-components (+ (var-get total-components) u1))
    
    ;; Record initial history event
    (map-set component-history
      { component-id: component-id, event-id: u1 }
      {
        event-type: "registration",
        location: initial-location,
        timestamp: block-height,
        description: "Component registered in tracking system",
        recorded-by: tx-sender,
        verification-hash: ""
      }
    )
    
    (ok component-id)
  )
)

;; Update component location in supply chain
(define-public (update-location
    (component-id (string-ascii 50))
    (new-location (string-ascii 100))
    (event-id uint)
    (description (string-ascii 200))
  )
  (let (
    (component (unwrap! (map-get? components { component-id: component-id }) ERR-NOT-FOUND))
  )
    ;; Update component location
    (map-set components
      { component-id: component-id }
      (merge component {
        current-location: new-location,
        last-updated: block-height
      })
    )
    
    ;; Record location update in history
    (map-set component-history
      { component-id: component-id, event-id: event-id }
      {
        event-type: "location-update",
        location: new-location,
        timestamp: block-height,
        description: description,
        recorded-by: tx-sender,
        verification-hash: ""
      }
    )
    
    (ok new-location)
  )
)

;; Verify component authenticity
(define-public (verify-authenticity
    (component-id (string-ascii 50))
    (verification-hash (string-ascii 64))
    (event-id uint)
  )
  (let (
    (component (unwrap! (map-get? components { component-id: component-id }) ERR-NOT-FOUND))
  )
    ;; Update component verification status
    (map-set components
      { component-id: component-id }
      (merge component {
        authenticity-verified: true,
        last-updated: block-height
      })
    )
    
    ;; Record verification in history
    (map-set component-history
      { component-id: component-id, event-id: event-id }
      {
        event-type: "authenticity-verification",
        location: (get current-location component),
        timestamp: block-height,
        description: "Component authenticity verified",
        recorded-by: tx-sender,
        verification-hash: verification-hash
      }
    )
    
    (ok true)
  )
)

;; Update component status
(define-public (update-status
    (component-id (string-ascii 50))
    (new-status uint)
    (event-id uint)
    (reason (string-ascii 200))
  )
  (let (
    (component (unwrap! (map-get? components { component-id: component-id }) ERR-NOT-FOUND))
  )
    ;; Validate status
    (asserts! (<= new-status STATUS-COMPROMISED) ERR-INVALID-STATUS)
    
    ;; Update component status
    (map-set components
      { component-id: component-id }
      (merge component {
        current-status: new-status,
        last-updated: block-height
      })
    )
    
    ;; Record status change in history
    (map-set component-history
      { component-id: component-id, event-id: event-id }
      {
        event-type: "status-change",
        location: (get current-location component),
        timestamp: block-height,
        description: reason,
        recorded-by: tx-sender,
        verification-hash: ""
      }
    )
    
    (ok new-status)
  )
)

;; Flag potential supply chain risk
(define-public (flag-risk
    (component-id (string-ascii 50))
    (assessment-id uint)
    (risk-level uint)
    (risk-factors (list 5 (string-ascii 50)))
    (mitigation-actions (string-ascii 200))
  )
  (begin
    ;; Validate risk level
    (asserts! (and (>= risk-level u1) (<= risk-level u5)) ERR-INVALID-CRITICALITY)
    
    ;; Record risk assessment
    (map-set risk-assessments
      { component-id: component-id, assessment-id: assessment-id }
      {
        risk-level: risk-level,
        risk-factors: risk-factors,
        mitigation-actions: mitigation-actions,
        assessed-by: tx-sender,
        assessment-date: block-height,
        validity-period: u1000 ;; Valid for 1000 blocks
      }
    )
    
    ;; Update security alert level if high risk
    (if (>= risk-level u4)
      (if (> risk-level (var-get security-alert-level))
        (var-set security-alert-level risk-level)
        true
      )
      true
    )
    
    (ok assessment-id)
  )
)

;; Authorize personnel for component access
(define-public (authorize-personnel
    (user principal)
    (access-level uint)
    (department (string-ascii 50))
    (validity-blocks uint)
  )
  (begin
    ;; Only contract owner can authorize
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    
    ;; Set authorization
    (map-set authorized-personnel
      { user: user }
      {
        access-level: access-level,
        department: department,
        authorized-by: tx-sender,
        authorization-date: block-height,
        expiry-date: (+ block-height validity-blocks),
        active: true
      }
    )
    
    (ok user)
  )
)

;; Set security alert level (emergency use)
(define-public (set-security-alert (level uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (asserts! (<= level u5) ERR-INVALID-STATUS)
    (var-set security-alert-level level)
    (ok level)
  )
)

;; Read-Only Functions

;; Get component information
(define-read-only (get-component-info (component-id (string-ascii 50)))
  (map-get? components { component-id: component-id })
)

;; Get component history event
(define-read-only (get-component-history
    (component-id (string-ascii 50))
    (event-id uint)
  )
  (map-get? component-history { component-id: component-id, event-id: event-id })
)

;; Get risk assessment
(define-read-only (get-risk-assessment
    (component-id (string-ascii 50))
    (assessment-id uint)
  )
  (map-get? risk-assessments { component-id: component-id, assessment-id: assessment-id })
)

;; Check if component is compromised
(define-read-only (is-component-compromised (component-id (string-ascii 50)))
  (match (map-get? components { component-id: component-id })
    component (is-eq (get current-status component) STATUS-COMPROMISED)
    false
  )
)

;; Check user authorization
(define-read-only (is-user-authorized
    (user principal)
    (required-level uint)
  )
  (match (map-get? authorized-personnel { user: user })
    auth (
      and
        (get active auth)
        (>= (get access-level auth) required-level)
        (< block-height (get expiry-date auth))
    )
    false
  )
)

;; Get total components count
(define-read-only (get-total-components)
  (var-get total-components)
)

;; Get current security alert level
(define-read-only (get-security-alert-level)
  (var-get security-alert-level)
)

;; Check if tracking is enabled
(define-read-only (is-tracking-enabled)
  (var-get tracking-enabled)
)

;; Get contract owner
(define-read-only (get-contract-owner)
  CONTRACT-OWNER
)

