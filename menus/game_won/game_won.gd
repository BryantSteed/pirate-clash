extends Node

# These two should be externally set at instantiaton time
var crystal_count: int
var time_left: float
var went_through_portal: bool

var score: float
var rank: String

# Full-screen overlays (640x360) with the letter drawn in place; shown over the background.
const RANK_TEXTURES := {
	"S": preload("res://art/S Rank.png"),
	"A": preload("res://art/A Rank.png"),
	"B": preload("res://art/B Rank.png"),
	"C": preload("res://art/C Rank.png"),
	"F": preload("res://art/F Rank.png"),
}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if went_through_portal:
		$DoorEntrance.play()
		$DoorEntrance.finished.connect(_on_entrance_finished)
	compute_rank()
	display_rank_letter()
	display_score_labels()
	if not went_through_portal:
		_on_entrance_finished()
	$"Restart Button".pressed.connect(OnRestartButtonPressed)	
	
func OnRestartButtonPressed() -> void:	
	get_tree().change_scene_to_file("res://levels/pirate_cave/pirate_cave.tscn")
	
func display_score_labels() -> void:
	$ScoreLabel.text = $ScoreLabel.text + str(int(self.score))
	$TimeLeftLabel.text = $TimeLeftLabel.text + str(int(self.time_left))
	$CrystalCountLabel.text = $CrystalCountLabel.text + str(crystal_count)
	
func display_rank_letter() -> void:
	# Unknown ranks fall back to F.
	$RankDisplay/RankLetter.texture = RANK_TEXTURES.get(rank, RANK_TEXTURES["F"])

func compute_rank() -> void:
	self.score = time_left + crystal_count
	if score >= 300:
		rank = "S"
	elif score >= 200:
		rank = "A"
	elif score >= 150:
		rank = "B"
	elif score >= 120:
		rank = "C"
	else:
		rank = "F"
	
func _on_entrance_finished() -> void:
	# One song per rank tier, matching the players under Music.
	match rank:
		"S":
			$Music/SRank.play()
		"A", "B":
			$Music/ABRank.play()
		_:
			$Music/CFRank.play()
