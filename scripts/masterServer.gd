extends HTTPRequest

signal server_registered();
signal server_retrieved(servers);

const MS_URL = "http://localhost/opencombat/ms/";
#const MS_URL = "http://opencombat.tuxfamily.org/ms/";

const TASK_NONE = 0;
const TASK_RETRIEVE = 1;
const TASK_REGISTER = 2;

var currentTask = TASK_NONE;

func _ready():
	set_use_threads(true);
	connect("request_completed", self, "on_request_completed");

func on_request_completed(result, response_code, headers, body):
	if (result != HTTPRequest.RESULT_SUCCESS):
		return;
	
	if (currentTask == TASK_RETRIEVE):
		var string = body.get_string_from_utf8();
		var servers = {};
		servers.parse_json(string);
		
		emit_signal("server_retrieved", servers);
	
	if (currentTask == TASK_REGISTER):
		emit_signal("server_registered");

func register_server(port, name):
	currentTask = TASK_REGISTER;
	
	cancel_request();
	request(MS_URL+"?do=register&port="+str(port)+"&name="+str(name).percent_encode());

func retrieve_server(filter = ''):
	currentTask = TASK_RETRIEVE;
	
	cancel_request();
	request(MS_URL+"?do=lists&search="+str(filter).percent_encode());
