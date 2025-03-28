;; Tender Publication Contract
;; Manages public procurement opportunities

(define-data-var last-tender-id uint u0)

;; Tender data structure
(define-map tenders
  { tender-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    department: principal,
    budget: uint,
    deadline: uint,
    status: (string-ascii 20),
    documents-hash: (buff 32),
    created-at: uint,
    updated-at: uint
  }
)

;; Tender amendments
(define-map tender-amendments
  { tender-id: uint, amendment-id: uint }
  {
    description: (string-ascii 500),
    documents-hash: (buff 32),
    timestamp: uint
  }
)

;; Track amendment count per tender
(define-map amendment-count
  { tender-id: uint }
  { count: uint }
)

;; Approved departments that can publish tenders
(define-map approved-departments
  { department: principal }
  { active: bool }
)

;; Initialize contract with admin
(define-data-var contract-admin principal tx-sender)

;; Add a department (only admin)
(define-public (add-department (department principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) (err u403))
    (ok (map-set approved-departments { department: department } { active: true }))
  )
)

;; Remove a department (only admin)
(define-public (remove-department (department principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) (err u403))
    (ok (map-set approved-departments { department: department } { active: false }))
  )
)

;; Check if a principal is an approved department
(define-read-only (is-approved-department (department principal))
  (default-to
    false
    (get active (map-get? approved-departments { department: department }))
  )
)

;; Publish a new tender (only approved departments)
(define-public (publish-tender
    (title (string-ascii 100))
    (description (string-ascii 500))
    (budget uint)
    (deadline uint)
    (documents-hash (buff 32)))
  (let
    (
      (new-id (+ (var-get last-tender-id) u1))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (is-approved-department tx-sender) (err u403))
    (asserts! (> budget u0) (err u1))
    (asserts! (> deadline current-time) (err u2))

    (var-set last-tender-id new-id)
    (map-set tenders
      { tender-id: new-id }
      {
        title: title,
        description: description,
        department: tx-sender,
        budget: budget,
        deadline: deadline,
        status: "OPEN",
        documents-hash: documents-hash,
        created-at: current-time,
        updated-at: current-time
      }
    )

    ;; Initialize amendment count
    (map-set amendment-count { tender-id: new-id } { count: u0 })

    (ok new-id)
  )
)

;; Amend a tender (only by the department that created it)
(define-public (amend-tender
    (tender-id uint)
    (description (string-ascii 500))
    (documents-hash (buff 32)))
  (let
    (
      (tender (unwrap! (map-get? tenders { tender-id: tender-id }) (err u404)))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (amendment-data (default-to { count: u0 } (map-get? amendment-count { tender-id: tender-id })))
      (new-amendment-id (+ (get count amendment-data) u1))
    )
    (asserts! (is-eq (get department tender) tx-sender) (err u403))
    (asserts! (is-eq (get status tender) "OPEN") (err u3))

    ;; Add amendment
    (map-set tender-amendments
      { tender-id: tender-id, amendment-id: new-amendment-id }
      {
        description: description,
        documents-hash: documents-hash,
        timestamp: current-time
      }
    )

    ;; Update amendment count
    (map-set amendment-count
      { tender-id: tender-id }
      { count: new-amendment-id }
    )

    ;; Update tender
    (map-set tenders
      { tender-id: tender-id }
      (merge tender { updated-at: current-time })
    )

    (ok new-amendment-id)
  )
)

;; Close a tender (only by the department that created it)
(define-public (close-tender (tender-id uint))
  (let
    (
      (tender (unwrap! (map-get? tenders { tender-id: tender-id }) (err u404)))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (is-eq (get department tender) tx-sender) (err u403))
    (asserts! (is-eq (get status tender) "OPEN") (err u3))

    ;; Update tender status
    (map-set tenders
      { tender-id: tender-id }
      (merge tender {
        status: "CLOSED",
        updated-at: current-time
      })
    )

    (ok true)
  )
)

;; Cancel a tender (only by the department that created it)
(define-public (cancel-tender (tender-id uint) (reason (string-ascii 500)))
  (let
    (
      (tender (unwrap! (map-get? tenders { tender-id: tender-id }) (err u404)))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (amendment-data (default-to { count: u0 } (map-get? amendment-count { tender-id: tender-id })))
      (new-amendment-id (+ (get count amendment-data) u1))
    )
    (asserts! (is-eq (get department tender) tx-sender) (err u403))
    (asserts! (is-eq (get status tender) "OPEN") (err u3))

    ;; Add cancellation reason as amendment
    (map-set tender-amendments
      { tender-id: tender-id, amendment-id: new-amendment-id }
      {
        description: reason,
        documents-hash: 0x0000000000000000000000000000000000000000000000000000000000000000,
        timestamp: current-time
      }
    )

    ;; Update amendment count
    (map-set amendment-count
      { tender-id: tender-id }
      { count: new-amendment-id }
    )

    ;; Update tender status
    (map-set tenders
      { tender-id: tender-id }
      (merge tender {
        status: "CANCELLED",
        updated-at: current-time
      })
    )

    (ok true)
  )
)

;; Get tender details
(define-read-only (get-tender (tender-id uint))
  (map-get? tenders { tender-id: tender-id })
)

;; Get tender amendment
(define-read-only (get-tender-amendment (tender-id uint) (amendment-id uint))
  (map-get? tender-amendments { tender-id: tender-id, amendment-id: amendment-id })
)

;; Get amendment count for a tender
(define-read-only (get-amendment-count (tender-id uint))
  (default-to
    { count: u0 }
    (map-get? amendment-count { tender-id: tender-id })
  )
)

;; Check if a tender is open
(define-read-only (is-tender-open (tender-id uint))
  (match (map-get? tenders { tender-id: tender-id })
    tender (is-eq (get status tender) "OPEN")
    false
  )
)

;; Check if tender deadline has passed
(define-read-only (is-tender-deadline-passed (tender-id uint))
  (match (map-get? tenders { tender-id: tender-id })
    tender (let
      (
        (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      )
      (> current-time (get deadline tender))
    )
    false
  )
)

