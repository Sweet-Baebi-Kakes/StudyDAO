
**Commit Messages:**
- Code: `feat: add digital certificate verification smart contract`
- README: `docs: add comprehensive documentation for EduCert system`

---

## Project 2: StudyDAO - Decentralized Study Group Governance

**Branch name:** `feature/study-group-governance`

**Clarity Contract:**
```clarity
;; StudyDAO - Decentralized Study Group Governance
;; Enables students to create and govern study groups with token-based voting

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-insufficient-tokens (err u104))
(define-constant err-proposal-ended (err u105))

;; Data structures
(define-map study-groups
  { group-id: uint }
  {
    name: (string-ascii 50),
    creator: principal,
    subject: (string-ascii 50),
    max-members: uint,
    current-members: uint,
    creation-block: uint,
    is-active: bool
  }
)

(define-map group-members
  { group-id: uint, member: principal }
  {
    join-date: uint,
    contribution-score: uint,
    voting-power: uint
  }
)

(define-map proposals
  { proposal-id: uint }
  {
    group-id: uint,
    proposer: principal,
    title: (string-ascii 100),
    description: (string-ascii 200),
    votes-for: uint,
    votes-against: uint,
    end-block: uint,
    executed: bool
  }
)

(define-map votes
  { proposal-id: uint, voter: principal }
  { vote: bool, voting-power: uint }
)

(define-data-var next-group-id uint u1)
(define-data-var next-proposal-id uint u1)

;; Create a new study group
(define-public (create-study-group 
  (name (string-ascii 50))
  (subject (string-ascii 50))
  (max-members uint)
)
  (let ((group-id (var-get next-group-id)))
    (map-set study-groups
      { group-id: group-id }
      {
        name: name,
        creator: tx-sender,
        subject: subject,
        max-members: max-members,
        current-members: u1,
        creation-block: block-height,
        is-active: true
      }
    )
    (map-set group-members
      { group-id: group-id, member: tx-sender }
      {
        join-date: block-height,
        contribution-score: u100,
        voting-power: u100
      }
    )
    (var-set next-group-id (+ group-id u1))
    (ok group-id)
  )
)

;; Join a study group
(define-public (join-group (group-id uint))
  (match (map-get? study-groups { group-id: group-id })
    group-data
    (if (and 
          (get is-active group-data)
          (< (get current-members group-data) (get max-members group-data))
          (is-none (map-get? group-members { group-id: group-id, member: tx-sender }))
        )
      (begin
        (map-set group-members
          { group-id: group-id, member: tx-sender }
          {
            join-date: block-height,
            contribution-score: u50,
            voting-power: u50
          }
        )
        (map-set study-groups
          { group-id: group-id }
          (merge group-data { current-members: (+ (get current-members group-data) u1) })
        )
        (ok true)
      )
      err-unauthorized
    )
    err-not-found
  )
)

;; Create a proposal
(define-public (create-proposal
  (group-id uint)
  (title (string-ascii 100))
  (description (string-ascii 200))
  (voting-period uint)
)
  (let ((proposal-id (var-get next-proposal-id)))
    (match (map-get? group-members { group-id: group-id, member: tx-sender })
      member-data
      (begin
        (map-set proposals
          { proposal-id: proposal-id }
          {
            group-id: group-id,
            proposer: tx-sender,
            title: title,
            description: description,
            votes-for: u0,
            votes-against: u0,
            end-block: (+ block-height voting-period),
            executed: false
          }
        )
        (var-set next-proposal-id (+ proposal-id u1))
        (ok proposal-id)
      )
      err-unauthorized
    )
  )
)

;; Vote on a proposal
(define-public (vote-on-proposal (proposal-id uint) (vote-for bool))
  (match (map-get? proposals { proposal-id: proposal-id })
    proposal-data
    (if (< block-height (get end-block proposal-data))
      (match (map-get? group-members { group-id: (get group-id proposal-data), member: tx-sender })
        member-data
        (let ((voting-power (get voting-power member-data)))
          (map-set votes
            { proposal-id: proposal-id, voter: tx-sender }
            { vote: vote-for, voting-power: voting-power }
          )
          (if vote-for
            (map-set proposals
              { proposal-id: proposal-id }
              (merge proposal-data { votes-for: (+ (get votes-for proposal-data) voting-power) })
            )
            (map-set proposals
              { proposal-id: proposal-id }
              (merge proposal-data { votes-against: (+ (get votes-against proposal-data) voting-power) })
            )
          )
          (ok true)
        )
        err-unauthorized
      )
      err-proposal-ended
    )
    err-not-found
  )
)

;; Update contribution score
(define-public (update-contribution-score (group-id uint) (member principal) (new-score uint))
  (match (map-get? study-groups { group-id: group-id })
    group-data
    (if (is-eq tx-sender (get creator group-data))
      (match (map-get? group-members { group-id: group-id, member: member })
        member-data
        (begin
          (map-set group-members
            { group-id: group-id, member: member }
            (merge member-data { 
              contribution-score: new-score,
              voting-power: new-score
            })
          )
          (ok true)
        )
        err-not-found
      )
      err-unauthorized
    )
    err-not-found
  )
)

;; Read-only functions
(define-read-only (get-study-group (group-id uint))
  (map-get? study-groups { group-id: group-id })
)

(define-read-only (get-member-info (group-id uint) (member principal))
  (map-get? group-members { group-id: group-id, member: member })
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals { proposal-id: proposal-id })
)