/*********************************************************
*
* File: Rx_VehicleFactory_GunEmplacement.uc
* Author: RenegadeX-Team
* Pojekt: Renegade-X UDK <www.renegade-x.com>
*
* Desc:
*
*
* ConfigFile:
*
*********************************************************
*
*********************************************************/
class Rx_VehicleFactory_GunEmplacement extends UTVehicleFactory;

var() byte OwningTeam;


function Activate(byte T)
{
	if ( !bDisabled )
	{
		TeamNum = OwningTeam;
		GotoState('Active');
	}
}

DefaultProperties
{
    Begin Object Name=SVehicleMesh
        SkeletalMesh=SkeletalMesh'RX_DEF_GunEmplacement.Mesh.SK_DEF_GunEmplacement'
		Translation=(X=0.0,Y=0.0,Z=-50.0)
    End Object

    Components.Remove(Sprite)

    VehicleClassPath="RenX_Game.Rx_Defence_GunEmplacement"
    DrawScale=1.0
}
