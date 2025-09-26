extends Node

# ================================
# == Exported Config and Stats ==
# ================================
@export var player_stats: PlayerStats
@export var current_job: JobResource = load("res://global/job_resource/unemploy.tres")
@export var income: float = 0
@export var total_assets: float = 0
@export var current_day: int = 0
@export var current_event: String

@export var rent: float = 50
@export var utilities: float = 25
@export var subscriptions: float = 20

# ================================
# == Runtime References/Storage ==
# ================================
#var work_action: WorkActionResource = null
#var schedule_track: Node = null
#var available_actions: Array[ActionResource] = []
#
#var scheduled_actions: Array[ScheduledAction] = []
#var action_log: Array[String] = []
#var current_day: int = 0

# =====================
# == Utility Getters ==
# =====================
var bills: float:
	get: return rent + utilities + subscriptions

# =========
# == Init ==
# =========
func _ready():
	if player_stats == null:
		player_stats = PlayerStats.new()
	# Optionally reset stats here
	# stats.reset()

# =======================
# == Action Scheduling ==
# =======================



# =============================
# == Apply and Execute Turn ==
# =============================
#func apply_day_schedule():
	#action_log.clear()
	#scheduled_actions.sort_custom(func(a, b): return a.start_slot < b.start_slot)
#
	#for scheduled in scheduled_actions:
		#_apply_scheduled_action(scheduled)
#
	#if current_day % 30 == 0:
		#total_assets += income
		#total_assets -= bills
		#action_log.append("Paid bills: $%.2f" % bills)
#
	#scheduled_actions.clear()
	#current_day += 1
#
	#if schedule_track:
		#schedule_track.clear_all_blocks()
	#else:
		#print("⚠️ ScheduleTrack reference not set in GameData.")
#
	#for entry in action_log:
		#print(entry)
#
#func _apply_scheduled_action(scheduled: ScheduledAction):
	#if scheduled.action is WorkActionResource:
		#_apply_work_income(scheduled)
#
	#var start_hour = scheduled.start_slot / 4.0
	#if start_hour >= 24:
		#return
#
	#scheduled.apply(stats, action_log)
#
#func _apply_work_income(scheduled: ScheduledAction):
	#var work = scheduled.action as WorkActionResource
	#var job = work.job
	#var hours = scheduled.length * 0.25
	#var earned = job.base_income_per_hour * hours
	#total_assets += earned
	#action_log.append("Worked at %s and earned $%.2f" % [job.name, earned])

# =======================
# == Load Action Assets ==
# =======================
#func load_actions():
	#var dir := DirAccess.open("res://data/actions")
	#if dir:
		#dir.list_dir_begin()
		#var file = dir.get_next()
		#while file != "":
			#if file.ends_with(".tres"):
				#var path = "res://data/actions/" + file
				#var action = load(path)
				#if action is ActionResource:
					#available_actions.append(action)
			#file = dir.get_next()
