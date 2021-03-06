//Edited by Dema 2017
// -----------------------------------------------------------------------------
// Includes
// --------

// SA-MP include
#include <a_samp>
#include <streamer>
#include <easydialog>
// For PlaySoundForPlayersInRange()
#include "../include/gl_common.inc"

// -----------------------------------------------------------------------------
// Defines
// -------
#define ELEVATOR_SPEED      (5.0)
#define DOORS_SPEED         (5.0)
#define ELEVATOR_WAIT_TIME  (5000)  

// Position defines
#define X_DOOR_R_OPENED     (289.542419)
#define X_DOOR_L_OPENED     (286.342407)
#define Y_DOOR_R_OPENED     (-1609.640991)
#define Y_DOOR_L_OPENED     (-1609.076049)

#define X_FDOOR_R_OPENED    (289.492431)
#define X_FDOOR_L_OPENED    (286.292419)
#define Y_FDOOR_R_OPENED    (-1609.870971)
#define Y_FDOOR_L_OPENED    (-1609.306030)

#define GROUND_Z_COORD      (18.755348)     // (33.825077)
#define X_ELEVATOR_POS      (287.942413)
#define Y_ELEVATOR_POS      (-1609.341064)

// Elevator state defines
#define ELEVATOR_STATE_IDLE     (0)
#define ELEVATOR_STATE_WAITING  (1)
#define ELEVATOR_STATE_MOVING   (2)

// Invalid floor define
#define INVALID_FLOOR           (-1)

// Used for chat text messages
#define COLOR_MESSAGE_YELLOW        0xFFDD00AA

// -----------------------------------------------------------------------------
// Constants
// ---------

// Elevator floor names for the 3D text labels
static FloorNames[14][] =
{
	"��������",
	"����",
	"������ ����",
	"������ ����",
	"������ ����",
	"��������� ����",
	"����� ����",
	"������ ����",
	"������� ����",
	"������� ����",
	"������� ����",
	"������� ����",
	"������������ ����",
	"����������� ����"
};

// Elevator floor Z heights
static Float:FloorZOffsets[14] =
{
    0.0, 		// Car Park
    15.069729,  // Ground Floor
    29.130733,	// First Floor
    33.630733,  // Second Floor = 29.130733 + 4.5
    38.130733,  // Third Floor = 33.630733 + 4.5
    42.630733,  // Fourth Floor = 38.130733 + 4.5
    47.130733,  // Fifth Floor = 42.630733 + 4.5
    51.630733,  // Sixth Floor = 47.130733 + 4.5
    56.130733,  // Seventh Floor = 51.630733 + 4.5
    60.630733,  // Eighth Floor = 56.130733 + 4.5
    65.130733,  // Ninth Floor = 60.630733 + 4.5
    69.630733,  // Tenth Floor = 65.130733 + 4.5
    74.130733,  // Eleventh Floor = 69.630733 + 4.5
    78.630733,  // Twelfth Floor = 74.130733 + 4.5
};

// -----------------------------------------------------------------------------
// Variables
// ---------
new Obj_Elevator,
	Obj_ElevatorDoors[2],
	Obj_FloorDoors[14][2];
	
new Text3D:Label_Elevator,
	Text3D:Label_Floors[14];
	
new ElevatorState,
	ElevatorFloor,
	ElevatorQueue[14],
	FloorRequestedBy[14],
	ElevatorBoostTimer;

// -----------------------------------------------------------------------------
// Function Forwards
// -----------------

// Public:
forward CallElevator(playerid, floorid);    // You can use INVALID_PLAYER_ID too.
forward ShowElevatorDialog(playerid);

// Private:
forward Elevator_Initialize();
forward Elevator_Destroy();

forward Elevator_OpenDoors();
forward Elevator_CloseDoors();
forward Floor_OpenDoors(floorid);
forward Floor_CloseDoors(floorid);

forward Elevator_MoveToFloor(floorid);
forward Elevator_Boost(floorid);        	// Increases the elevator speed until it reaches 'floorid'.
forward Elevator_TurnToIdle();

forward ReadNextFloorInQueue();
forward RemoveFirstQueueFloor();
forward AddFloorToQueue(floorid);
forward IsFloorInQueue(floorid);
forward ResetElevatorQueue();

forward DidPlayerRequestElevator(playerid);

forward Float:GetElevatorZCoordForFloor(floorid);
forward Float:GetDoorsZCoordForFloor(floorid);

public OnFilterScriptInit()
{
	for(new i; i != MAX_PLAYERS; i++)
	{
	    if(0 == IsPlayerConnected(i) || 0 != IsPlayerNPC(i))
	        continue;
	        
        RemoveBuildingForPlayer(i, 1226, 265.481, -1581.1, 32.9311, 5.0);
    	RemoveBuildingForPlayer(i, 6518, 280.297, -1606.2, 72.3984, 250.0);
	}
	ResetElevatorQueue();
	Elevator_Initialize();
    print("  |--  LS BeachSide Elevator");
    print("  |---------------------------------------------------");
	return 1;
}

public OnFilterScriptExit()
{
	Elevator_Destroy();
	return 1;
}

public OnPlayerConnect(playerid)
{
    RemoveBuildingForPlayer(playerid, 1226, 265.481, -1581.1, 32.9311, 5.0);
    RemoveBuildingForPlayer(playerid, 6518, 280.297, -1606.2, 72.3984, 250.0);
	return 1;
}

public OnObjectMoved(objectid)
{
	// Create variables
    new Float:x, Float:y, Float:z;
    
    // Loop
	for(new i; i < sizeof(Obj_FloorDoors); i ++)
	{
	    // Check if the object that moved was one of the elevator floor doors
		if(objectid == Obj_FloorDoors[i][0])
		{
		    GetObjectPos(Obj_FloorDoors[i][0], x, y, z);

            // Some floor doors have shut, move the elevator to next floor in queue:
            if (y < Y_DOOR_L_OPENED - 0.5)
		    {
				Elevator_MoveToFloor(ElevatorQueue[0]);
				RemoveFirstQueueFloor();
			}
		}
	}

	if(objectid == Obj_Elevator)   // The elevator reached the specified floor.
	{
	    KillTimer(ElevatorBoostTimer);  // Kills the timer, in case the elevator reached the floor before boost.

	    FloorRequestedBy[ElevatorFloor] = INVALID_PLAYER_ID;

	    Elevator_OpenDoors();
	    Floor_OpenDoors(ElevatorFloor);

	    GetObjectPos(Obj_Elevator, x, y, z);
	    Label_Elevator	=
			CreateDynamic3DTextLabel("{CCCCCC}������� '{FFFFFF}~k~~CONVERSATION_YES~{CCCCCC}' ����� ������������", 0xCCCCCCAA, X_ELEVATOR_POS + 1.6, Y_ELEVATOR_POS - 1.85, z - 0.4, 4.0, INVALID_PLAYER_ID, INVALID_VEHICLE_ID, 1, 0, 0);

	    ElevatorState 	= ELEVATOR_STATE_WAITING;
	    SetTimer("Elevator_TurnToIdle", ELEVATOR_WAIT_TIME, 0);
	}

	return 1;
}

Dialog:Elevator_Beachside(playerid, response, listitem, inputtext[])
{
	if(!response)
 		return 1;

	if(FloorRequestedBy[listitem] != INVALID_PLAYER_ID || IsFloorInQueue(listitem))
 		GameTextForPlayer(playerid, "~r~The floor is already in the queue", 3500, 4);
	else if(DidPlayerRequestElevator(playerid))
	    GameTextForPlayer(playerid, "~r~You already requested the elevator", 3500, 4);
	else
 		CallElevator(playerid, listitem);

	return 1;
}

public OnPlayerKeyStateChange(playerid, newkeys, oldkeys)
{
	// Check if the player is not in a vehicle and pressed the conversation yes key (Y by default)
	if (!IsPlayerInAnyVehicle(playerid) && (newkeys & KEY_YES))
	{
	    // Create variables and get the players current position
	    new Float:pos[3];
	    GetPlayerPos(playerid, pos[0], pos[1], pos[2]);
	    
	    // For debug
	    //printf("X = %0.2f | Y = %0.2f | Z = %0.2f", pos[0], pos[1], pos[2]);

        // Check if the player is using the button inside the elevator
	    if (pos[1] > (Y_ELEVATOR_POS - 1.8) && pos[1] < (Y_ELEVATOR_POS + 1.8) && pos[0] < (X_ELEVATOR_POS + 1.8) && pos[0] > (X_ELEVATOR_POS - 1.8))
	    {
	        // The player is using the button inside the elevator
	        // --------------------------------------------------
	        
	        // Show the elevator dialog to the player
	        ShowElevatorDialog(playerid);
	    }
		else
		{
		    // Check if the player is using the button on one of the floors
		    if(pos[1] < (Y_ELEVATOR_POS - 1.81) && pos[1] > (Y_ELEVATOR_POS - 3.8) && pos[0] > (X_ELEVATOR_POS + 1.21) && pos[0] < (X_ELEVATOR_POS + 3.8))
		    {
		        // The player is most likely using an elevator floor button... check which floor
		        // -----------------------------------------------------------------------------
		        
		        // Create variable with the number of floors to check (total floors minus 1)
				new i = 13;

				// Loop
				while(pos[2] < GetDoorsZCoordForFloor(i) + 3.5 && i > 0)
				    i --;

				if(i == 0 && pos[2] < GetDoorsZCoordForFloor(0) + 2.0)
				    i = -1;

				if (i <= 12)
				{
				    // Check if the elevator is not moving (idle or waiting)
				    if (ElevatorState != ELEVATOR_STATE_MOVING)
				    {
				        // Check if the elevator is already on the floor it was called from
				        if (ElevatorFloor == i + 1)
				        {
	                        SendClientMessage(playerid, COLOR_MESSAGE_YELLOW, "* ���� ��������� �� ����� �����, ������� ������ � ������� '{FFFFFF}~k~~CONVERSATION_YES~{CCCCCC}'");
	                        return 1;
				        }
				    }

				    // Call function to call the elevator to the floor
					CallElevator(playerid, i + 1);

					// Display gametext message to the player
					GameTextForPlayer(playerid, "~n~~n~~n~~n~~n~~n~~n~~n~~w~Please Wait", 3000, 3);

					// Create variable for formatted message
					new strTempString[128];
					
					// Check if the elevator is moving
					if (ElevatorState == ELEVATOR_STATE_MOVING)
					{
					    // Format chat text message
						format(strTempString, sizeof(strTempString), "* �� ������� ����, ������ �� �������� �� %s.", FloorNames[ElevatorFloor]);
					}
					else
					{
					    // Check if the floor is the car park
					    if (ElevatorFloor == 0)
					    {
					    	// Format chat text message
							format(strTempString, sizeof(strTempString), "* �� ������� ����, ������ �� ��������� �� %s.", FloorNames[ElevatorFloor]);
						}
						else
						{
					    	// Format chat text message
							format(strTempString, sizeof(strTempString), "* �� ������� ����, ������ �� ��������� �� %s.", FloorNames[ElevatorFloor]);
						}
					}
					
					// Display formatted chat text message to the player
					SendClientMessage(playerid, COLOR_MESSAGE_YELLOW, strTempString);

					// Exit here (return 1 so this callback is processed in other scripts)
					return 1;
				}
		    }
		}
	}

    // Exit here (return 1 so this callback is processed in other scripts)
	return 1;
}

// ------------------------ Functions ------------------------
stock Elevator_Initialize()
{
	// Create the elevator and elevator door objects
	Obj_Elevator 			= CreateObject(18755, X_ELEVATOR_POS, Y_ELEVATOR_POS, GROUND_Z_COORD, 0.000000, 0.000000, 80.000000);
	Obj_ElevatorDoors[0] 	= CreateObject(18757, X_ELEVATOR_POS, Y_ELEVATOR_POS, GROUND_Z_COORD, 0.000000, 0.000000, 80.000000);
	Obj_ElevatorDoors[1] 	= CreateObject(18756, X_ELEVATOR_POS, Y_ELEVATOR_POS, GROUND_Z_COORD, 0.000000, 0.000000, 80.000000);

	// Create the 3D text label for inside the elevator
	Label_Elevator =
		CreateDynamic3DTextLabel("{CCCCCC}������� '{FFFFFF}~k~~CONVERSATION_YES~{CCCCCC}' ����� ������������", 0xCCCCCCAA, X_ELEVATOR_POS + 1.6, Y_ELEVATOR_POS - 1.85, GROUND_Z_COORD - 0.4, 4.0, INVALID_PLAYER_ID, INVALID_VEHICLE_ID, 1, 0, 0);

	// Create variables
	new string[128], Float:z;

	// Loop
	for (new i; i < sizeof(Obj_FloorDoors); i ++)
	{
	    // Create elevator floor door objects
	    Obj_FloorDoors[i][0] 	= CreateObject(18757, X_ELEVATOR_POS, Y_ELEVATOR_POS - 0.245, GetDoorsZCoordForFloor(i) + 0.05, 0.000000, 0.000000, 80.000000);
		Obj_FloorDoors[i][1] 	= CreateObject(18756, X_ELEVATOR_POS, Y_ELEVATOR_POS - 0.245, GetDoorsZCoordForFloor(i) + 0.05, 0.000000, 0.000000, 80.000000);

        // Format string for the floor 3D text label
		format(string, sizeof(string), "{CCCCCC}[%s]\n{CCCCCC}������� '{FFFFFF}~k~~CONVERSATION_YES~{CCCCCC}' ��� ������ �����", FloorNames[i]);

		// Get label Z position
		z = GetDoorsZCoordForFloor(i);

		// Create floor label
		Label_Floors[i] =
            CreateDynamic3DTextLabel(string, 0xCCCCCCAA, X_ELEVATOR_POS + 2, Y_ELEVATOR_POS -3, z - 0.2, 10.5, INVALID_PLAYER_ID, INVALID_VEHICLE_ID, 1, 0, 0);
	}

	// Open the car park floor doors and the elevator doors
	Floor_OpenDoors(0);
	Elevator_OpenDoors();

	// Exit here
	return 1;
}

stock Elevator_Destroy()
{
	// Destroys the elevator.

	DestroyObject(Obj_Elevator);
	DestroyObject(Obj_ElevatorDoors[0]);
	DestroyObject(Obj_ElevatorDoors[1]);
	DestroyDynamic3DTextLabel(Label_Elevator);

	for(new i; i < sizeof(Obj_FloorDoors); i ++)
	{
	    DestroyObject(Obj_FloorDoors[i][0]);
		DestroyObject(Obj_FloorDoors[i][1]);
		DestroyDynamic3DTextLabel(Label_Floors[i]);
	}

	return 1;
}

stock Elevator_OpenDoors()
{
	// Opens the elevator's doors.

	new Float:x, Float:y, Float:z;

	GetObjectPos(Obj_ElevatorDoors[0], x, y, z);
	MoveObject(Obj_ElevatorDoors[0], X_DOOR_L_OPENED, Y_DOOR_L_OPENED, z, DOORS_SPEED);
	MoveObject(Obj_ElevatorDoors[1], X_DOOR_R_OPENED, Y_DOOR_R_OPENED, z, DOORS_SPEED);

	return 1;
}

stock Elevator_CloseDoors()
{
    // Closes the elevator's doors.

    if(ElevatorState == ELEVATOR_STATE_MOVING)
	    return 0;

    new Float:x, Float:y, Float:z;

	GetObjectPos(Obj_ElevatorDoors[0], x, y, z);
	MoveObject(Obj_ElevatorDoors[0], X_ELEVATOR_POS, Y_ELEVATOR_POS, z, DOORS_SPEED);
	MoveObject(Obj_ElevatorDoors[1], X_ELEVATOR_POS, Y_ELEVATOR_POS, z, DOORS_SPEED);

	return 1;
}

stock Floor_OpenDoors(floorid)
{
    // Opens the doors at the specified floor.

    MoveObject(Obj_FloorDoors[floorid][0], X_FDOOR_L_OPENED, Y_FDOOR_L_OPENED, GetDoorsZCoordForFloor(floorid) + 0.05, DOORS_SPEED);
	MoveObject(Obj_FloorDoors[floorid][1], X_FDOOR_R_OPENED, Y_FDOOR_R_OPENED, GetDoorsZCoordForFloor(floorid) + 0.05, DOORS_SPEED);
	
	PlaySoundForPlayersInRange(6401, 50.0, X_ELEVATOR_POS, Y_ELEVATOR_POS, GetDoorsZCoordForFloor(floorid) + 5.0);

	return 1;
}

stock Floor_CloseDoors(floorid)
{
    // Closes the doors at the specified floor.

    MoveObject(Obj_FloorDoors[floorid][0], X_ELEVATOR_POS, Y_ELEVATOR_POS - 0.245, GetDoorsZCoordForFloor(floorid) + 0.05, DOORS_SPEED);
	MoveObject(Obj_FloorDoors[floorid][1], X_ELEVATOR_POS, Y_ELEVATOR_POS - 0.245, GetDoorsZCoordForFloor(floorid) + 0.05, DOORS_SPEED);
	
	PlaySoundForPlayersInRange(6401, 50.0, X_ELEVATOR_POS, Y_ELEVATOR_POS, GetDoorsZCoordForFloor(floorid) + 5.0);

	return 1;
}

stock Elevator_MoveToFloor(floorid)
{
	// Moves the elevator to specified floor (doors are meant to be already closed).

	ElevatorState = ELEVATOR_STATE_MOVING;
	ElevatorFloor = floorid;

	// Move the elevator slowly, to give time to clients to sync the object surfing. Then, boost it up:
	MoveObject(Obj_Elevator, X_ELEVATOR_POS, Y_ELEVATOR_POS, GetElevatorZCoordForFloor(floorid), 0.25);
    MoveObject(Obj_ElevatorDoors[0], X_ELEVATOR_POS, Y_ELEVATOR_POS, GetDoorsZCoordForFloor(floorid), 0.25);
    MoveObject(Obj_ElevatorDoors[1], X_ELEVATOR_POS, Y_ELEVATOR_POS, GetDoorsZCoordForFloor(floorid), 0.25);
    DestroyDynamic3DTextLabel(Label_Elevator);

	ElevatorBoostTimer = SetTimerEx("Elevator_Boost", 2000, 0, "i", floorid);

	return 1;
}

public Elevator_Boost(floorid)
{
	// Increases the elevator's speed until it reaches 'floorid'
	StopObject(Obj_Elevator);
	StopObject(Obj_ElevatorDoors[0]);
	StopObject(Obj_ElevatorDoors[1]);
	
	MoveObject(Obj_Elevator, X_ELEVATOR_POS, Y_ELEVATOR_POS, GetElevatorZCoordForFloor(floorid), ELEVATOR_SPEED);
    MoveObject(Obj_ElevatorDoors[0], X_ELEVATOR_POS, Y_ELEVATOR_POS, GetDoorsZCoordForFloor(floorid), ELEVATOR_SPEED);
    MoveObject(Obj_ElevatorDoors[1], X_ELEVATOR_POS, Y_ELEVATOR_POS, GetDoorsZCoordForFloor(floorid), ELEVATOR_SPEED);

	return 1;
}

public Elevator_TurnToIdle()
{
	ElevatorState = ELEVATOR_STATE_IDLE;
	ReadNextFloorInQueue();

	return 1;
}

stock RemoveFirstQueueFloor()
{
	// Removes the data in ElevatorQueue[0], and reorders the queue accordingly.

	for(new i; i < sizeof(ElevatorQueue) - 1; i ++)
	    ElevatorQueue[i] = ElevatorQueue[i + 1];

	ElevatorQueue[sizeof(ElevatorQueue) - 1] = INVALID_FLOOR;

	return 1;
}

stock AddFloorToQueue(floorid)
{
 	// Adds 'floorid' at the end of the queue.

	// Scan for the first empty space:
	new slot = -1;
	for(new i; i < sizeof(ElevatorQueue); i ++)
	{
	    if(ElevatorQueue[i] == INVALID_FLOOR)
	    {
	        slot = i;
	        break;
	    }
	}

	if(slot != -1)
	{
	    ElevatorQueue[slot] = floorid;

     	// If needed, move the elevator.
	    if(ElevatorState == ELEVATOR_STATE_IDLE)
	        ReadNextFloorInQueue();

	    return 1;
	}

	return 0;
}

stock ResetElevatorQueue()
{
	// Resets the queue.

	for(new i; i < sizeof(ElevatorQueue); i ++)
	{
	    ElevatorQueue[i] 	= INVALID_FLOOR;
	    FloorRequestedBy[i] = INVALID_PLAYER_ID;
	}

	return 1;
}

stock IsFloorInQueue(floorid)
{
	// Checks if the specified floor is currently part of the queue.

	for(new i; i < sizeof(ElevatorQueue); i ++)
	    if(ElevatorQueue[i] == floorid)
	        return 1;

	return 0;
}

stock ReadNextFloorInQueue()
{
	// Reads the next floor in the queue, closes doors, and goes to it.

	if(ElevatorState != ELEVATOR_STATE_IDLE || ElevatorQueue[0] == INVALID_FLOOR)
	    return 0;

	Elevator_CloseDoors();
	Floor_CloseDoors(ElevatorFloor);

	return 1;
}

stock DidPlayerRequestElevator(playerid)
{
	for(new i; i < sizeof(FloorRequestedBy); i ++)
	    if(FloorRequestedBy[i] == playerid)
	        return 1;

	return 0;
}

stock ShowElevatorDialog(playerid)
{
	new string[512];
	for(new i; i < sizeof(ElevatorQueue); i ++)
	{
	    if(FloorRequestedBy[i] != INVALID_PLAYER_ID)
	        strcat(string, "{FF0000}");

	    strcat(string, FloorNames[i]);
	    strcat(string, "\n");
	}
    ShowDialog(playerid, Show:<Elevator_Beachside>, DIALOG_STYLE_LIST, "����", string, "�������", "������");
	return 1;
}

stock CallElevator(playerid, floorid)
{
	// Calls the elevator (also used with the elevator dialog).

	if(FloorRequestedBy[floorid] != INVALID_PLAYER_ID || IsFloorInQueue(floorid))
	    return 0;

	FloorRequestedBy[floorid] = playerid;
	AddFloorToQueue(floorid);

	return 1;
}

stock Float:GetElevatorZCoordForFloor(floorid)
{
	// Return Z height value
    return (GROUND_Z_COORD + FloorZOffsets[floorid]);
}

stock Float:GetDoorsZCoordForFloor(floorid)
{
    // Return Z height value
	return (GROUND_Z_COORD + FloorZOffsets[floorid]);
}

