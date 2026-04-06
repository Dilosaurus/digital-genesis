class_name VoteSystem
extends RefCounted

const VOTE_DURATION: float = 10.0  # seconds


## Represents a vote in progress
class VoteContext:
	var vote_id: String = ""
	var prompt: String = ""
	var options: Array[String] = []  # option labels
	var votes: Dictionary = {}       # peer_id -> option_index
	var time_remaining: float = VOTE_DURATION
	var is_resolved: bool = false
	var result_index: int = -1       # winning option index
	var required_voters: Array[int] = []  # peer_ids who should vote


## Create a new vote context
static func create_vote(vote_id: String, prompt: String, options: Array[String], voter_peer_ids: Array[int]) -> VoteContext:
	var ctx = VoteContext.new()
	ctx.vote_id = vote_id
	ctx.prompt = prompt
	ctx.options = options
	ctx.required_voters = voter_peer_ids.duplicate()
	ctx.time_remaining = VOTE_DURATION
	return ctx


## Cast a vote. Returns true if vote was accepted.
static func cast_vote(ctx: VoteContext, peer_id: int, option_index: int) -> bool:
	if ctx.is_resolved:
		return false
	if peer_id not in ctx.required_voters:
		return false
	if option_index < 0 or option_index >= ctx.options.size():
		return false
	ctx.votes[peer_id] = option_index
	return true


## Check if all required voters have voted
static func all_voted(ctx: VoteContext) -> bool:
	for pid in ctx.required_voters:
		if pid not in ctx.votes:
			return false
	return true


## Resolve the vote. Returns the winning option index.
## tie_breaker_peer_id: if provided, this player's vote wins on tie (boss target, highest HP)
static func resolve(ctx: VoteContext, tie_breaker_peer_id: int = -1) -> int:
	if ctx.is_resolved:
		return ctx.result_index

	# Count votes per option
	var counts: Array[int] = []
	for i in ctx.options.size():
		counts.append(0)

	for peer_id in ctx.votes:
		var opt: int = ctx.votes[peer_id]
		if opt >= 0 and opt < counts.size():
			counts[opt] += 1

	# Default uncast votes to option 0 (first option, usually "accept" or the safer choice)
	var uncast_count := 0
	for pid in ctx.required_voters:
		if pid not in ctx.votes:
			uncast_count += 1
	counts[0] += uncast_count

	# Find the winner
	var max_votes := 0
	var max_index := 0
	var is_tie := false
	for i in counts.size():
		if counts[i] > max_votes:
			max_votes = counts[i]
			max_index = i
			is_tie = false
		elif counts[i] == max_votes and counts[i] > 0:
			is_tie = true

	# Tie-breaking
	if is_tie:
		if tie_breaker_peer_id >= 0 and tie_breaker_peer_id in ctx.votes:
			max_index = ctx.votes[tie_breaker_peer_id]
		else:
			# Random tie-break among tied options
			var tied: Array[int] = []
			for i in counts.size():
				if counts[i] == max_votes:
					tied.append(i)
			max_index = tied[randi() % tied.size()]

	ctx.result_index = max_index
	ctx.is_resolved = true
	return max_index


## Get a summary of the vote for display
static func get_vote_summary(ctx: VoteContext) -> Dictionary:
	var counts: Array[int] = []
	for i in ctx.options.size():
		counts.append(0)
	for peer_id in ctx.votes:
		var opt: int = ctx.votes[peer_id]
		if opt >= 0 and opt < counts.size():
			counts[opt] += 1
	return {
		"vote_id": ctx.vote_id,
		"prompt": ctx.prompt,
		"options": ctx.options,
		"counts": counts,
		"total_voters": ctx.required_voters.size(),
		"votes_cast": ctx.votes.size(),
		"is_resolved": ctx.is_resolved,
		"result_index": ctx.result_index,
		"time_remaining": ctx.time_remaining,
	}
