;; StudyDAO - Decentralized Study Group Governance
;; Enables students to create and govern study groups with token-based voting

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-insufficient-tokens (err u104))
(define-constant err-proposal-ended (err u105))
(define-constant err-invalid-input (err u106))

;; Data structures
(define-map study-groups
  { group-id: uint }
  {
    name: (string-ascii 50),
    creator: principal,
    subject: (string-ascii 50),
    max-members: uint,
    current-members: uint,
    creation-time: uint,
    is-active: bool
  })

(define-map group-members
  { group-id: uint, member: principal }
  {
    join-time: uint,
    contribution-score: uint,
    voting-power: uint
  })

(define-map proposals
  { proposal-id: uint }
  {
    group-id: uint,
    proposer: principal,
    title: (string-ascii 100),
    description: (string-ascii 200),
    votes-for: uint,
    votes-against: uint,
    voting-duration: uint,
    creation-time: uint,
    executed: bool
  })

(define-map votes
  { proposal-id: uint, voter: principal }
  { vote: bool, voting-power: uint })

;; Data variables
(define-data-var next-group-id uint u1)
(define-data-var next-proposal-id uint u1)
(define-data-var global-time uint u0)

;; Helper function to increment time (simulates block progression)
(define-private (increment-time)
  (begin
    (var-set global-time (+ (var-get global-time) u1))
    (var-get global-time)))

;; Create a new study group
(define-public (create-study-group 
  (name (string-ascii 50))
  (subject (string-ascii 50))
  (max-members uint))
  (let ((group-id (var-get next-group-id))
        (current-time (increment-time)))
    (asserts! (> max-members u0) err-invalid-input)
    (asserts! (> (len name) u0) err-invalid-input)
    (asserts! (> (len subject) u0) err-invalid-input)
    
    (map-set study-groups
      { group-id: group-id }
      {
        name: name,
        creator: tx-sender,
        subject: subject,
        max-members: max-members,
        current-members: u1,
        creation-time: current-time,
        is-active: true
      })
    
    (map-set group-members
      { group-id: group-id, member: tx-sender }
      {
        join-time: current-time,
        contribution-score: u100,
        voting-power: u100
      })
    
    (var-set next-group-id (+ group-id u1))
    (ok group-id)))

;; Join a study group
(define-public (join-group (group-id uint))
  (let ((group-data-opt (map-get? study-groups { group-id: group-id }))
        (current-time (increment-time)))
    (match group-data-opt
      group-data
      (begin
        (asserts! (get is-active group-data) err-unauthorized)
        (asserts! (< (get current-members group-data) (get max-members group-data)) err-unauthorized)
        (asserts! (is-none (map-get? group-members { group-id: group-id, member: tx-sender })) err-already-exists)
        
        (map-set group-members
          { group-id: group-id, member: tx-sender }
          {
            join-time: current-time,
            contribution-score: u50,
            voting-power: u50
          })
        
        (map-set study-groups
          { group-id: group-id }
          (merge group-data { current-members: (+ (get current-members group-data) u1) }))
        
        (ok true))
      err-not-found)))

;; Create a proposal
(define-public (create-proposal
  (group-id uint)
  (title (string-ascii 100))
  (description (string-ascii 200))
  (voting-duration uint))
  (let ((proposal-id (var-get next-proposal-id))
        (current-time (increment-time)))
    (asserts! (> voting-duration u0) err-invalid-input)
    (asserts! (> (len title) u0) err-invalid-input)
    
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
            voting-duration: voting-duration,
            creation-time: current-time,
            executed: false
          })
        
        (var-set next-proposal-id (+ proposal-id u1))
        (ok proposal-id))
      err-unauthorized)))

;; Vote on a proposal
(define-public (vote-on-proposal (proposal-id uint) (vote-for bool))
  (let ((current-time (var-get global-time)))
    (match (map-get? proposals { proposal-id: proposal-id })
      proposal-data
      (begin
        (asserts! (< current-time (+ (get creation-time proposal-data) (get voting-duration proposal-data))) err-proposal-ended)
        (asserts! (is-none (map-get? votes { proposal-id: proposal-id, voter: tx-sender })) err-already-exists)
        
        (match (map-get? group-members { group-id: (get group-id proposal-data), member: tx-sender })
          member-data
          (let ((voting-power (get voting-power member-data)))
            (map-set votes
              { proposal-id: proposal-id, voter: tx-sender }
              { vote: vote-for, voting-power: voting-power })
            
            (if vote-for
              (map-set proposals
                { proposal-id: proposal-id }
                (merge proposal-data { votes-for: (+ (get votes-for proposal-data) voting-power) }))
              (map-set proposals
                { proposal-id: proposal-id }
                (merge proposal-data { votes-against: (+ (get votes-against proposal-data) voting-power) })))
            
            (ok true))
          err-unauthorized))
      err-not-found)))

;; Update contribution score (only group creator can do this)
(define-public (update-contribution-score (group-id uint) (member principal) (new-score uint))
  (match (map-get? study-groups { group-id: group-id })
    group-data
    (begin
      (asserts! (is-eq tx-sender (get creator group-data)) err-unauthorized)
      
      (match (map-get? group-members { group-id: group-id, member: member })
        member-data
        (begin
          (map-set group-members
            { group-id: group-id, member: member }
            (merge member-data {
              contribution-score: new-score,
              voting-power: new-score
            }))
          (ok true))
        err-not-found))
    err-not-found))

;; Leave a study group
(define-public (leave-group (group-id uint))
  (match (map-get? study-groups { group-id: group-id })
    group-data
    (begin
      (asserts! (is-some (map-get? group-members { group-id: group-id, member: tx-sender })) err-not-found)
      (asserts! (not (is-eq tx-sender (get creator group-data))) err-unauthorized)
      
      (map-delete group-members { group-id: group-id, member: tx-sender })
      (map-set study-groups
        { group-id: group-id }
        (merge group-data { current-members: (- (get current-members group-data) u1) }))
      
      (ok true))
    err-not-found))

;; Deactivate a study group (only creator can do this)
(define-public (deactivate-group (group-id uint))
  (match (map-get? study-groups { group-id: group-id })
    group-data
    (begin
      (asserts! (is-eq tx-sender (get creator group-data)) err-unauthorized)
      
      (map-set study-groups
        { group-id: group-id }
        (merge group-data { is-active: false }))
      
      (ok true))
    err-not-found))

;; Read-only functions
(define-read-only (get-study-group (group-id uint))
  (map-get? study-groups { group-id: group-id }))

(define-read-only (get-member-info (group-id uint) (member principal))
  (map-get? group-members { group-id: group-id, member: member }))

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals { proposal-id: proposal-id }))

(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? votes { proposal-id: proposal-id, voter: voter }))

(define-read-only (get-current-time)
  (var-get global-time))

(define-read-only (is-proposal-active (proposal-id uint))
  (match (map-get? proposals { proposal-id: proposal-id })
    proposal-data
    (< (var-get global-time) (+ (get creation-time proposal-data) (get voting-duration proposal-data)))
    false))

(define-read-only (get-proposal-result (proposal-id uint))
  (match (map-get? proposals { proposal-id: proposal-id })
    proposal-data
    (ok {
      votes-for: (get votes-for proposal-data),
      votes-against: (get votes-against proposal-data),
      passed: (> (get votes-for proposal-data) (get votes-against proposal-data))
    })
    err-not-found))
