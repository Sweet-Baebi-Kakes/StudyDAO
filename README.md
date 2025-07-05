# StudyDAO - Decentralized Study Group Governance

A decentralized autonomous organization (DAO) platform for managing study groups with token-based governance and contribution tracking.

## Features

- **Study Group Creation**: Students can create subject-specific study groups
- **Membership Management**: Join groups with member limits and tracking
- **Proposal System**: Create and vote on group decisions and activities
- **Contribution Scoring**: Track and reward member contributions
- **Voting Power**: Voting power based on contribution scores
- **Decentralized Governance**: Democratic decision-making for group activities

## Smart Contract Functions

### Public Functions

- `create-study-group(name, subject, max-members)` - Create a new study group
- `join-group(group-id)` - Join an existing study group
- `create-proposal(group-id, title, description, voting-period)` - Create a proposal
- `vote-on-proposal(proposal-id, vote-for)` - Vote on proposals
- `update-contribution-score(group-id, member, new-score)` - Update member contributions

### Read-Only Functions

- `get-study-group(group-id)` - Get study group information
- `get-member-info(group-id, member)` - Get member details
- `get-proposal(proposal-id)` - Get proposal information

## Usage

1. Create or join study groups for specific subjects
2. Participate in group activities to earn contribution scores
3. Create proposals for group decisions (study schedules, resources, etc.)
4. Vote on proposals using your earned voting power
5. Build a reputation through consistent contributions

## Development

```bash
clarinet check
clarinet test