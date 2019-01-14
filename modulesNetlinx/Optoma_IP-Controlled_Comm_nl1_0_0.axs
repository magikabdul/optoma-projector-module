MODULE_NAME='Optoma_IP-Controlled_Comm_nl1_0_0' (DEV vdvProjector,
												 DEV dvProjector)
(***********************************************************)
(*  FILE CREATED ON: 01/12/2019  AT: 12:18:40              *)
(***********************************************************)
(*  FILE_LAST_MODIFIED_ON: 01/12/2019  AT: 20:21:16        *)
(***********************************************************)
#INCLUDE 'SNAPI'
#INCLUDE 'amx_panel_control_v2'
(***********************************************************)
(*          DEVICE NUMBER DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_DEVICE

#DEFINE DEFINE_DEVICE_PARAMETERS
#IF_NOT_DEFINED DEFINE_DEVICE_PARAMETERS
	vdvProjector
	dvProjector
#END_IF
(***********************************************************)
(*               CONSTANT DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_CONSTANT

#DEFINE DEFINE_CONSTANT_PARAMETERS
#IF_NOT_DEFINED DEFINE_CONSTANT_PARAMETERS

#END_IF

VOLATILE INTEGER tlBufferTx = 1
VOLATILE INTEGER tlBufferRx = 2
VOLATILE INTEGER tlMaintainConnection = 3
VOLATILE INTEGER tlSetOffline = 4
(***********************************************************)
(*              STRUCTURE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_TYPE

STRUCT __BUFFER {
	CHAR tx[1000]
	CHAR rx[1000]
}

STRUCT __SETTINGS_IP {
	CHAR address[20]
	LONG port
}

STRUCT __OPTOMA {
	INTEGER isOnline
	INTEGER isPassback
	__SETTINGS_IP ip
	__BUFFER buffer
}
(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE

#DEFINE DEFINE_VARIABLE_PARAMETERS
#IF_NOT_DEFINED DEFINE_VARIABLE_PARAMETERS

#END_IF

VOLATILE __OPTOMA optoma

VOLATILE LONG ltimesBufferTx[] = {200};
VOLATILE LONG ltimesBufferRx[] = {100};
VOLATILE LONG ltimesMaintainConnection[] = {10000};
VOLATILE LONG ltimesSetOffline[] = {15000};
(***********************************************************)
(*                FUNCTIONS CODE GOES BELOW                *)
(***********************************************************)
DEFINE_FUNCTION fnDebug(CHAR message[]) {
	SEND_STRING 0, "'Optoma Module: ', message"
}

DEFINE_FUNCTION setControlProperties() {
	optoma.ip.port = 21
	optoma.isPassback = TRUE
	
	IF(TIMELINE_ACTIVE(tlBufferTx) == FALSE)
		TIMELINE_CREATE(tlBufferTx, ltimesBufferTx, LENGTH_ARRAY(ltimesBufferTx), TIMELINE_ABSOLUTE, TIMELINE_REPEAT)
	IF(TIMELINE_ACTIVE(tlBufferRx) == FALSE)
		TIMELINE_CREATE(tlBufferRx, ltimesBufferRx, LENGTH_ARRAY(ltimesBufferRx), TIMELINE_ABSOLUTE, TIMELINE_REPEAT)

	IF(TIMELINE_ACTIVE(tlMaintainConnection) == FALSE)
		TIMELINE_CREATE(tlMaintainConnection, ltimesMaintainConnection, LENGTH_ARRAY(ltimesMaintainConnection), TIMELINE_ABSOLUTE, TIMELINE_REPEAT)
}

DEFINE_FUNCTION doClientConnect() {

	IF(optoma.isOnline == FALSE)
	{
		IF(LENGTH_STRING(optoma.ip.address) < 7)
		{
			fnDebug('doClientConnect - no IP address provided')
			RETURN
		}

		IF(optoma.ip.port == 0)
		{
			fnDebug('doClientConnect - no IP port provided')
			RETURN
		}

		fnDebug("'doClientConnect - atempting connect to ', optoma.ip.address, ', on port ', ITOA(optoma.ip.port), '...'")

		IP_CLIENT_OPEN(dvProjector.PORT, optoma.ip.address, optoma.ip.port, IP_TCP)
		
		IF(TIMELINE_ACTIVE(tlBufferTx) == FALSE)
			TIMELINE_CREATE(tlBufferTx, ltimesBufferTx, LENGTH_ARRAY(ltimesBufferTx), TIMELINE_ABSOLUTE, TIMELINE_REPEAT)
		IF(TIMELINE_ACTIVE(tlBufferRx) == FALSE)
			TIMELINE_CREATE(tlBufferRx, ltimesBufferRx, LENGTH_ARRAY(ltimesBufferRx), TIMELINE_ABSOLUTE, TIMELINE_REPEAT)

		IF(TIMELINE_ACTIVE(tlMaintainConnection) == FALSE)
			TIMELINE_CREATE(tlMaintainConnection, ltimesMaintainConnection, LENGTH_ARRAY(ltimesMaintainConnection), TIMELINE_ABSOLUTE, TIMELINE_REPEAT)
	}
}

DEFINE_FUNCTION bufferTxAddCommand(CHAR controlCommand[]) {
	optoma.buffer.tx = "optoma.buffer.tx, controlCommand, $0D"
}

(***********************************************************)
(*                 STARTUP CODE GOES BELOW                 *)
(***********************************************************)
DEFINE_START

setControlProperties()
(***********************************************************)
(*                  THE EVENTS GO BELOW                    *)
(***********************************************************)
DEFINE_EVENT

//---------------------------------------------------------------------------------------------------------------------------------------------------------------
// 																																	 error debuging to diagnostic																													    						   realDeviceStatus
//---------------------------------------------------------------------------------------------------------------------------------------------------------------
DATA_EVENT[dvProjector]
{
	ONERROR:
	{
		SWITCH(DATA.NUMBER)
		{
			CASE 2:
				fnDebug("'doClientConnect - connection error: ', 'General failure (out of memory)'")
			CASE 4:
				fnDebug("'doClientConnect - connection error: ', 'Unknown host'")
			CASE 6:
				fnDebug("'doClientConnect - connection error: ', 'Connection refused'")
			CASE 7:
				fnDebug("'doClientConnect - connection error: ', 'Connection timed out'")
			CASE 8:
				fnDebug("'doClientConnect - connection error: ', 'Unknown connection error'")
			CASE 9:
				fnDebug("'doClientConnect - connection error: ', 'Already closed'")
			CASE 14:
				fnDebug("'doClientConnect - connection error: ', 'Local port already used'")
			CASE 16:
				fnDebug("'doClientConnect - connection error: ', 'Too many open sockets'")
			CASE 17:
				fnDebug("'doClientConnect - connection error: ', 'Local Port Not Open'")
		}
	}
}

//---------------------------------------------------------------------------------------------------------------------------------------------------------------
// 																																																														    						   realDeviceStatus
//---------------------------------------------------------------------------------------------------------------------------------------------------------------
TIMELINE_EVENT[tlMaintainConnection]
{
	IF(FIND_STRING(optoma.buffer.tx, "$7E,$30,$30,$31,$35,$30,$20,$31", 1) == FALSE)
		bufferTxAddCommand("$7E,$30,$30,$31,$35,$30,$20,$31")
	
	doClientConnect()
}

//---------------------------------------------------------------------------------------------------------------------------------------------------------------
// 																																																														    						   realDeviceStatus
//---------------------------------------------------------------------------------------------------------------------------------------------------------------
TIMELINE_EVENT[tlSetOffline]
{
	optoma.isOnline = FALSE

	IP_CLIENT_CLOSE(dvProjector.PORT)

	OFF[vdvProjector, DATA_INITIALIZED]
	OFF[vdvProjector, DEVICE_COMMUNICATING]
	
	OFF[vdvProjector, POWER_FB]
}

//---------------------------------------------------------------------------------------------------------------------------------------------------------------
// 																																																														    						   realDeviceStatus
//---------------------------------------------------------------------------------------------------------------------------------------------------------------
DATA_EVENT[dvProjector]
{
	ONLINE:
	{
		optoma.isOnline = TRUE
		ON[vdvProjector, DATA_INITIALIZED]
	}
	
	OFFLINE:
	{
		optoma.isOnline = FALSE
		IP_CLIENT_CLOSE(dvProjector.PORT)
		
		OFF[vdvProjector, DATA_INITIALIZED]
		OFF[vdvProjector, DEVICE_COMMUNICATING]
		
		OFF[vdvProjector, POWER_FB]
	}
	
	STRING:
	{
		optoma.buffer.rx = "optoma.buffer.rx, DATA.TEXT"
		
		IF(optoma.isPassback)
			SEND_COMMAND vdvProjector, DATA.TEXT
	}
}

//---------------------------------------------------------------------------------------------------------------------------------------------------------------
// 																																																														    						   realDeviceStatus
//---------------------------------------------------------------------------------------------------------------------------------------------------------------
DATA_EVENT[vdvProjector]
{
	COMMAND:
	{
		STACK_VAR INTEGER idx
		
		IF(FIND_STRING(DATA.TEXT, 'PASSBACK-', 1))
		{
			REMOVE_STRING(DATA.TEXT, 'PASSBACK-', 1)
			
			SELECT
			{
				ACTIVE(DATA.TEXT == '0'): optoma.isPassback = FALSE
				ACTIVE(DATA.TEXT == '1'): optoma.isPassback = TRUE
			}
		}
		
		ELSE IF(FIND_STRING(DATA.TEXT, 'REINIT', 1))
		{
			IP_CLIENT_CLOSE(dvProjector.PORT)
			optoma.isOnline = FALSE
			
			OFF[vdvProjector, DATA_INITIALIZED]
			OFF[vdvProjector, DEVICE_COMMUNICATING]
			
			OFF[vdvProjector, POWER_FB]
			
			FOR(idx = 1; idx <= 4; idx++)
			{
				IF(TIMELINE_ACTIVE(idx))
					TIMELINE_KILL(idx)
			}
			
			optoma.buffer.tx = ''
			optoma.buffer.rx = ''
			
			WAIT 50
				doClientConnect()
		}
		
		ELSE IF(FIND_STRING(DATA.TEXT, 'PROPERTY-', 1))
		{
			REMOVE_STRING(DATA.TEXT, 'PROPERTY-', 1)
			
			IF(FIND_STRING(DATA.TEXT, 'IP_Address,', 1))
			{
				REMOVE_STRING(DATA.TEXT, 'IP_Address,', 1)
				optoma.ip.address = DATA.TEXT
			}
			
			ELSE IF(FIND_STRING(DATA.TEXT, 'IP_Port,', 1))
			{
				REMOVE_STRING(DATA.TEXT, 'IP_Port,', 1)
				optoma.ip.port = ATOI(DATA.TEXT)
			}
		}
		
		ELSE IF(FIND_STRING(DATA.TEXT, 'PASSTHRU-', 1))
		{
			REMOVE_STRING(DATA.TEXT, 'PASSTHRU-', 1)
			bufferTxAddCommand(DATA.TEXT)
		}
	}
}

//---------------------------------------------------------------------------------------------------------------------------------------------------------------
// 																																																														    						   realDeviceStatus
//---------------------------------------------------------------------------------------------------------------------------------------------------------------
TIMELINE_EVENT[tlBufferTx]
{
	STACK_VAR CHAR txCommand[100]

	IF(optoma.isOnline)
	{
		IF(FIND_STRING(optoma.buffer.tx, "$0D", 1))
		{
			txCommand = REMOVE_STRING(optoma.buffer.tx, "$0D", 1)
			fnDebug("'doClientConnect - Command send to: ', txCommand")
			SEND_STRING dvProjector, txCommand
		}
	}
	
	//ELSE
	//{
	//	IF(FIND_STRING(optoma.buffer.tx, "$7E,$30,$30,$31,$35,$30,$20,$31,$0D", 1))
	//	{
	//		SEND_STRING dvProjector, "$7E,$30,$30,$31,$35,$30,$20,$31,$0D"
	//	}
	//}
}

//---------------------------------------------------------------------------------------------------------------------------------------------------------------
// 																																																														    						   realDeviceStatus
//---------------------------------------------------------------------------------------------------------------------------------------------------------------
TIMELINE_EVENT[tlBufferRx]
{
	STACK_VAR CHAR rxCommand[100]
	
	IF(FIND_STRING(optoma.buffer.rx, "$0D", 1))
	{
		IF(TIMELINE_ACTIVE(tlSetOffline))
			TIMELINE_SET(tlSetOffline, 0)
		ELSE
			TIMELINE_CREATE(tlSetOffline, ltimesSetOffline, LENGTH_ARRAY(ltimesSetOffline), TIMELINE_ABSOLUTE, TIMELINE_ONCE)
			
		REMOVE_STRING(optoma.buffer.rx, "$0D", 1)
	}
}

//---------------------------------------------------------------------------------------------------------------------------------------------------------------
// 																																																														    						   realDeviceStatus
//---------------------------------------------------------------------------------------------------------------------------------------------------------------
CHANNEL_EVENT[vdvProjector, 0]
{
	ON:
	{
		SWITCH(CHANNEL.CHANNEL)
		{
			CASE PWR_ON:
				bufferTxAddCommand("$7E,$30,$30,$30,$30,$20,$31")
			CASE PWR_OFF:
				bufferTxAddCommand("$7E,$30,$30,$30,$30,$20,$32")
		}
	}
}