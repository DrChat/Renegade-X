class Rx_WeaponAttachment extends UTWeaponAttachment;

var const AnimSet DefaultWeaponAnimSet;
var const name    DefaultAimProfileName;
var       AnimSet WeaponAnimSet;
var       name    AimProfileName;

/** If true, pawn will always be "relaxed" while using this weapon. */
var       bool    bDontAim;


/*********************************************************************************************
 Empty Shell Ejection! -- Vipeax
********************************************************************************************* */

/** Holds the name of the socket to attach the particle to */
var name					ShellEjectSocket;

/** PSC and Templates*/

var ParticleSystemComponent	ShellEjectPSC;
var ParticleSystem			ShellEjectPSCTemplate, ShellEjectAltPSCTemplate;
var bool					bShellEjectPSCLoops;


/** How long the eject particle should be there */
var float					ShellEjectDuration;


/** Holds the vector location of the socket to attach the forearm on the 3rd person character */
var vector					LeftHandIKSocketLocation;

/** Holds the name of the socket to attach the forearm on the 3rd person character */
var name					LeftHandIKSocket;

simulated event PostBeginPlay()
{
	super.PostBeginPlay();
	if( WeaponAnimSet == none )
	{
		WeaponAnimSet = DefaultWeaponAnimSet;
		//`logd("No Weapon AnimSet Setup for"@Class);
	}
	if( AimProfileName == 'none' )
	{
		AimProfileName = DefaultAimProfileName;
		//`logd("No Aim Profile Name Setup for"@Class);
	}
}

event Tick( float DeltaTime ) 
{
	local vector tempVec;
	local Rotator tempRot;
	
	if (Mesh.GetSocketByName(LeftHandIKSocket) != None)
	{
		Mesh.GetSocketWorldLocationAndRotation(LeftHandIKSocket, tempVec, tempRot, 0);
		LeftHandIKSocketLocation = tempVec;
	}
	else
	{
		LeftHandIKSocketLocation = tempVec - tempVec;
	}
	
	super.Tick(DeltaTime);
}

simulated function AttachTo(UTPawn OwnerPawn) 
{  
	local Rx_Pawn RxP; 
	
	RxP = Rx_Pawn(OwnerPawn);
	
	super.AttachTo(OwnerPawn);

	if (ShellEjectSocket != '')
	{
		if (ShellEjectPSCTemplate != None || ShellEjectAltPSCTemplate != None)
		{
			ShellEjectPSC = new(self) class'UTParticleSystemComponent';
			ShellEjectPSC.bAutoActivate = false;
			ShellEjectPSC.SetOwnerNoSee(true);
			Mesh.AttachComponentToSocket(ShellEjectPSC, ShellEjectSocket);
		}
	}

	if( RxP != none )
	{
		RxP.bAlwaysRelaxed = bDontAim;
		if (bDontAim)
		{
			RxP.ResetRelaxStance();
		}
		RxP.SetAnimSet(WeaponAnimSet, AimProfileName);
	}
}

simulated function DetachFrom( SkeletalMeshComponent MeshCpnt )
{
	super.DetachFrom(MeshCpnt);
	
	if ( Mesh != None) {
		if(MuzzleFlashPSC != None) {
			MuzzleFlashPSC.DeactivateSystem();
		}
		if (ShellEjectPSC != None) {
			Mesh.DetachComponent(ShellEjectPSC);
		}	
	}

	if( Rx_Pawn(Owner) != none ) {
		//`log("Setting DefaultAnimSet");
		Rx_Pawn(Owner).SetAnimSet(DefaultWeaponAnimSet, DefaultAimProfileName );
	}
}

simulated function ShellEjectTimer()
{

	if (ShellEjectPSC != none && (!bShellEjectPSCLoops) )
	{
		ShellEjectPSC.DeactivateSystem();
	}
}

/**
 * Causes the shell eject particle to turn on and setup a time to
 * turn it back off again.
 */
simulated function CauseShellEjection()
{
	local ParticleSystem ShellTemplate;

	if (ShellEjectPSC != none)
	{
		if ( !bShellEjectPSCLoops || !ShellEjectPSC.bIsActive)
		{
			if (Instigator != None && Instigator.FiringMode == 1 && ShellEjectAltPSCTemplate != None)
			{
				ShellTemplate = ShellEjectAltPSCTemplate;
			}
			else
			{
				ShellTemplate = ShellEjectPSCTemplate;
			}
			if (ShellTemplate != ShellEjectPSC.Template)
			{
				ShellEjectPSC.SetTemplate(ShellTemplate);
			}
			
			ShellEjectPSC.ActivateSystem();
		}
	}

	SetTimer(ShellEjectDuration,false,'ShellEjectTimer');
}

simulated function ThirdPersonFireEffects(vector HitLocation)
{
	local Rx_Weapon weapon;
	
	if ( EffectIsRelevant(Location,false,MaxFireEffectDistance) )
	{
		CauseShellEjection();
	}
	Super.ThirdPersonFireEffects(HitLocation);

	if(Instigator != None && Instigator.Weapon != None) {
		weapon = Rx_Weapon(Instigator.Weapon);
		weapon.ShakeView();
	}
}

simulated function bool EffectIsRelevant(vector SpawnLocation, bool bForceDedicated, optional float VisibleCullDistance=5000.0, optional float HiddenCullDistance=350.0 )
{
	return super.EffectIsRelevant( owner.location, bForceDedicated, VisibleCullDistance, HiddenCullDistance );
}

DefaultProperties
{
	DefaultWeaponAnimSet  = AnimSet'RX_CH_Animations.Anims.AS_WeapProfile_Unarmed'
	DefaultAimProfileName = Unarmed
	WeaponAnimSet         = none
	bDontAim             = false
	
	ShellEjectPSCTemplate=none
	ShellEjectDuration = 0.1
	ShellEjectSocket = ShellEjectSocket
	
	LeftHandIKSocket = ForeArmIK
}