// This is a comment
// uncomment the line below if you want to write a filterscript
#define FILTERSCRIPT

#include <a_samp>
#include <dc_cmd>
#include <sscanf2>

// HOLDING(keys)
#define HOLDING(%0) \
	((newkeys & (%0)) == (%0))
	
// PRESSED(keys)
#define PRESSED(%0) \
	(((newkeys & (%0)) == (%0)) && ((oldkeys & (%0)) != (%0)))
	
// PRESSING(keyVariable, keys)
#define PRESSING(%0,%1) \
	(%0 & (%1))
	
#define RELEASED(%0) \
	(((newkeys & (%0)) != (%0)) && ((oldkeys & (%0)) == (%0)))
	
#if defined FILTERSCRIPT

public OnFilterScriptInit()
{
	print("\n--------------------------------------");
	print(" [FS] by DEMA (TEST SYSTEM)");
	print("--------------------------------------\n");
	return 1;
}

public OnFilterScriptExit()
{
	return 1;
}

#else

main()
{
	print("\n----------------------------------");
	print(" Blank Gamemode by your name here");
	print("----------------------------------\n");
}

#endif

public OnGameModeInit()
{
	return 1;
}

public OnGameModeExit()
{
	return 1;
}

public OnUnoccupiedVehicleUpdate(vehicleid, playerid, passenger_seat, Float:new_x, Float:new_y, Float:new_z, Float:vel_x, Float:vel_y, Float:vel_z)
{
    // Check if it moved far
    /*if(GetVehicleDistanceFromPoint(vehicleid, new_x, new_y, new_z) > 10.0)
    {
        new Float: x,
            Float: y,
            Float: z;
            
        GetVehiclePos(vehicleid, x, y, z);
        SetVehiclePos(vehicleid, x, y, z);
        SendClientMessage(playerid, -1, "Телепорт на 50 метров! Block");
		return 0;
    }

	new mes[144];
	format(mes, sizeof(mes), "OnUnoccupiedVehicleUpdate(%i, %i, %i, %f, %f,%f,%f,%f,%f)", vehicleid, playerid, passenger_seat, new_x, new_y, new_z, vel_x, vel_y, vel_z);
	SendClientMessage(playerid, -1, mes);*/
    return 1;
}

CMD:d_attach(playerid, params[])
{
	new boneid,
		model;
		
	if(sscanf(params, "ii", boneid, model))
	    return SendClientMessage(playerid, -1, "/d_attach [boneid] [model]");

    SetPlayerAttachedObject(playerid, 8, model, boneid);
    EditAttachedObject(playerid, 8);
	return 1;
}
CMD:carry(playerid, params[])
{
    SetPlayerSpecialAction(playerid, SPECIAL_ACTION_CARRY);
	return 1;
}

CMD:smoke(playerid, params[])
{
	
    ApplyAnimation(playerid, "GANGS", "SMKCIG_PRTL", 4.1, 0, 0, 0, 0, 0, 1);
	return 1;
}

public OnPlayerEditAttachedObject(playerid, response, index, modelid, boneid, Float:fOffsetX, Float:fOffsetY, Float:fOffsetZ, Float:fRotX, Float:fRotY, Float:fRotZ, Float:fScaleX, Float:fScaleY, Float:fScaleZ)
{
	if(response)
	    printf("SetPlayerAttachedObject(playerid, %i, %i, %i, %f, %f, %f, %f, %f, %f, %f, %f, %f);",
			index, modelid, boneid, fOffsetX, fOffsetY, fOffsetZ, fRotX, fRotY, fRotZ, fScaleX, fScaleY, fScaleZ);
	return 1;
}

public OnPlayerKeyStateChange(playerid, newkeys, oldkeys)
{
	if(PRESSING(newkeys, 128))
	{
	    SetPlayerDrunkLevel(playerid, 50000);
	}
	else if(PRESSING(oldkeys, 128))
	{
	    SetPlayerDrunkLevel(playerid, 1000);
	}
	return 1;
}
