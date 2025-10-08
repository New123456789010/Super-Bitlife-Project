extends Node

signal got_out_side_1st_time_signal(data)

# Event Dialogue 
signal start_timeline(timeline: Array)   # start dialogue/event
signal advance                           # request next step
signal input_submitted(key: String, value: String)  # generic input for any variable
signal choice_made(index: int)           # choice selected
signal external_signal(name: String)     # pass signals outward
signal timeline_ended
signal dialogue_finished
