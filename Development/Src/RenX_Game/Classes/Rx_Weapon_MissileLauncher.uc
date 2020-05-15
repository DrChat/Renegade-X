class Rx_Weapon_MissileLauncher extends Rx_Weapon_Reloadable;




/** Class of the rocket to use when seeking */
var class<UTProjectile> SeekingRocketClass;

var	SoundCue WeaponDistantFireSnd;	// A second firing sound to be played when weapon fires. (Used for distant sound)


/*********************************************************************************************
 * Weapon lock on support
 ********************************************************************************************* */

// ---------------------------------  Targeting/Lock on vars. -------------------------------------- //
var bool                   bLockedOnTarget;           /* When true, this weapon is locked on target */
var bool                   bTargetLockingActive;      /* If true, weapon will try to lock onto targets */
var Actor                  LastPendingTarget;         /* What last tick test "target" is current pending to be locked on to */
var Actor                  PendingLockedTarget;       /* What "target" is current pending to be locked on to */
var Actor                  LockedTarget;              /* What "target" is this weapon locked on to */
var PlayerReplicationInfo  LockedTargetPRI;           /* if player is targeted then his PRI will be stored here */
var(Locking) float         LockTolerance;
var protected float        LastLockedOnTime;          /* How long since the Lock Target has been valid */
var protected float        LastTargetLockCheckTime;   /* Last time target lock was checked */
var() float                LockCheckTime;             /* The frequency with which we will check for a lock */
var() float                LockAcquireTime;           /* How long does the player need to target an actor to lock on to it*/
var() float                LockRange;                 /* How far out should we be considering actors for a lock */
var() float                StayLocked;                /* How long target stay locked before losing it*/
var float                  PendingLockedTargetTime;   /* When did the pending Target become valid */
var float                  LastValidTargetTime;       /* When was the last time we had a valid target */
var float                  LockAim;                   /* angle for locking for lock targets */
var float                  ConsoleLockAim;            /* angle for locking for lock targets when on Console */
var SoundCue               LockLostSound;             /* Sound Effects to play when Lock lost*/
var Soundcue               LockAcquiredSound;         /* Sound Effects to play when Locking */
var bool                   LockingStart;              /* if true then locking state was started */

var MaterialInstanceConstant LockedOnCrosshairMIC;


replication
{
	if (Role == ROLE_Authority && bNetDirty)
		bLockedOnTarget, LockedTarget, PendingLockedTarget;
}


/*********************************************************************************************
 * Target Locking
 *********************************************************************************************/

simulated function GetWeaponDebug( out Array<String> DebugInfo )
{
	Super.GetWeaponDebug(DebugInfo);

	DebugInfo[DebugInfo.Length] = "Locked: "@bLockedOnTarget@LockedTarget@LastLockedontime@(WorldInfo.TimeSeconds-LastLockedOnTime);
	DebugInfo[DebugInfo.Length] = "Pending:"@PendingLockedTarget@PendingLockedTargetTime@WorldInfo.TimeSeconds;
}

simulated function FireAmmunition()
{
	Super.FireAmmunition();
	WeaponPlaySound( WeaponDistantFireSnd );

	if ( Role == ROLE_Authority )
	{
		AdjustLockTarget( none );
		LastValidTargetTime = 0;
		PendingLockedTarget = None;
		LastLockedOnTime = 0;
		PendingLockedTargetTime = 0;
	}
}


simulated function DrawLockedOn( HUD H )
{
    local vector2d CrosshairSize;
    local float x, y;
    local LinearColor LC; //nBab
	local vector ScreenLoc; 
	local bool bTargetBehindUs; 
	
	//set initial color based on settings (nBab)
	LC.A = 1.f;
	switch (Rx_HUD(Rx_Controller(Instigator.Controller).myHUD).SystemSettingsHandler.GetCrosshairColor())
	{
		//white
		case 0:
			LC.R = 1.f;
			LC.G = 1.f;
			LC.B = 1.f;
			break;
		//orange
		case 1:
			LC.R = 2.f;
			LC.G = 0.5f;
			LC.B = 0.f;
			break;
		//violet
		case 2:
			LC.R = 2.f;
			LC.G = 0.f;
			LC.B = 2.f;
			break;
		//blue
		case 3:
			LC.R = 0.f;
			LC.G = 0.f;
			LC.B = 2.f;
			break;
		//cyan
		case 4:
			LC.R = 0.f;
			LC.G = 2.f;
			LC.B = 2.f;
			break;	
	}
	CrosshairMIC.SetVectorParameterValue('Reticle_Colour', LC);
	LockedOnCrosshairMIC.SetVectorParameterValue('Reticle_Colour', LC);

   	if (H == none || H.Canvas == none)
      	return;

    CrosshairSize.Y = CrosshairHeight;
    CrosshairSize.X = CrosshairWidth;


	X = H.Canvas.ClipX * 0.5 - (CrosshairSize.X * 0.5);
	Y = H.Canvas.ClipY * 0.5 - (CrosshairSize.Y * 0.5);
    if ( LockedOnCrosshairMIC != none )
    {
        H.Canvas.SetPos(x, y);
        H.Canvas.DrawMaterialTile(CrosshairMIC,CrosshairSize.X, CrosshairSize.Y,0.0,0.0,1.0,1.0);
        H.Canvas.SetPos(x, y);
        H.Canvas.DrawMaterialTile(LockedOnCrosshairMIC,CrosshairSize.X, CrosshairSize.Y,0.0,0.0,1.0,1.0);
		if(LockedTarget != none)
			{
				bTargetBehindUs = class'Rx_Utils'.static.OrientationOfLocAndRotToBLocation(Rx_Controller(Instigator.Controller).ViewTarget.Location,Instigator.Controller.Rotation,LockedTarget.location) < -0.5;
			
				if(!bTargetBehindUs)
				{
				LC.R = 10.f;
				LC.G = 0.f;
				LC.B = 0.f;
				CrosshairMIC.SetVectorParameterValue('Reticle_Colour', LC);
				ScreenLoc = LockedTarget.location; 
				ScreenLoc = H.Canvas.Project(ScreenLoc);
				H.Canvas.SetPos( ScreenLoc.X - CrosshairWidth/2, ScreenLoc.Y - CrosshairWidth/2 );
				H.Canvas.DrawMaterialTile(CrosshairMIC, CrosshairWidth, CrosshairHeight);	
				}
			}
        DrawHitIndicator(H,x,y);
    }
}


/**
 *  This function is used to adjust the LockTarget.
 */
function AdjustLockTarget(actor NewLockTarget)
{
	if ( LockedTarget == NewLockTarget )
	{
		// no need to update
		return;
	}

	if (NewLockTarget == None)
	{
		// Clear the lock
		if (bLockedOnTarget)
		{
			LockedTarget = None;

			bLockedOnTarget = false;

			if (LockLostSound != None && Instigator != None && Instigator.IsHumanControlled() )
			{
				PlayerController(Instigator.Controller).ClientPlaySound(LockLostSound);
			}
		}
	}
	else
	{
		// Set the lcok
		bLockedOnTarget = true;
		LockedTarget = NewLockTarget;
		LockedTargetPRI = (Pawn(NewLockTarget) != None) ? Pawn(NewLockTarget).PlayerReplicationInfo : None;
		if ( LockAcquiredSound != None && Instigator != None  && Instigator.IsHumanControlled() )
		{
			PlayerController(Instigator.Controller).ClientPlaySound(LockAcquiredSound);
		}
	}
}

/**
* Given an potential target TA determine if we can lock on to it.  By default only allow locking on
* to pawns.  
*/
simulated function bool CanLockOnTo(Actor TA)
{
	if ( (TA == None) || !TA.bProjTarget || TA.bDeleteMe || (Pawn(TA) == None) || (TA == Instigator) || (Pawn(TA).Health <= 0) 
			|| TA.IsInState('Stealthed') || TA.IsInState('BeenShot') || Rx_Pawn(TA) != none || Rx_Sentinel(TA) != None || Rx_Sentinel_Obelisk_Laser_Base(TA) != None) //|| Rx_SupportVehicle(TA) != none ) //Because the dropoff Chinook is a mess. 
	{
		return false;
	}

	return ( (WorldInfo.Game == None) || !WorldInfo.Game.bTeamGame || (WorldInfo.GRI == None) || !WorldInfo.GRI.OnSameTeam(Instigator,TA) );
}


/**
  * Check target locking - server-side only
  */
event Tick( FLOAT DeltaTime )
{
	if ( bTargetLockingActive && ( WorldInfo.TimeSeconds > LastTargetLockCheckTime + LockCheckTime ) )
	{
		LastTargetLockCheckTime = WorldInfo.TimeSeconds;
		CheckTargetLock();
	}
}


/**
* This function checks to see if we are locked on a target
*/
function CheckTargetLock()
{
	local Pawn P, LockedPawn;
	local Actor BestTarget, HitActor, TA;
	local UDKBot BotController;
	local vector StartTrace, EndTrace, Aim, HitLocation, HitNormal;
	local rotator AimRot;
	local float BestAim, BestDist;

	if ( (Instigator == None) || (Instigator.Controller == None) || (self != Instigator.Weapon) )
	{
		return;
	}

	if ( Instigator.bNoWeaponFiring )
	{
		AdjustLockTarget(None);
		PendingLockedTarget = None;
		return;
	}

	// support keeping lock as players get onto hoverboard
	if ( LockedTarget != None )
	{
		if ( LockedTarget.bDeleteMe )
		{
			if ( (LockedTargetPRI != None) && (UTVehicle_Hoverboard(LockedTarget) != None) )
			{
				// find the appropriate pawn
				for ( P=WorldInfo.PawnList; P!=None; P=P.NextPawn )
				{
					if ( P.PlayerReplicationInfo == LockedTargetPRI )
					{
						AdjustLockTarget((Vehicle(P) != None) ? None : P);
						break;
					}
				}
			}
			else
			{
				AdjustLockTarget(None);
			}
		}
		else 
		{
			LockedPawn = Pawn(LockedTarget);
			if ( (LockedPawn != None) && (LockedPawn.DrivenVehicle != None) )
			{
				AdjustLockTarget(UTVehicle_Hoverboard(LockedPawn.DrivenVehicle));
			}
		}
	}

	BestTarget = None;
	BotController = UDKBot(Instigator.Controller);
	if ( BotController != None )
	{
		// only try locking onto bot's target
		if ( (BotController.Focus != None) && CanLockOnTo(BotController.Focus) )
		{
			BestTarget = BotController.Focus;
		}
	}
	else
	{
		// Begin by tracing the shot to see if it hits anyone
		Instigator.Controller.GetPlayerViewPoint( StartTrace, AimRot );
		Aim = vector(AimRot);
		StartTrace=StartTrace+Aim*150; 
		EndTrace = StartTrace + Aim * LockRange;
		HitActor = Trace(HitLocation, HitNormal, EndTrace, StartTrace, true,,, TRACEFLAG_Bullet);

		// Check for a hit
		if ( (HitActor == None) || !CanLockOnTo(HitActor) )
		{
			// We didn't hit a valid target, have the controller attempt to pick a good target
			BestAim = ((UDKPlayerController(Instigator.Controller) != None) && UDKPlayerController(Instigator.Controller).bConsolePlayer) ? ConsoleLockAim : LockAim;
			BestDist = 0.0;
			TA = Instigator.Controller.PickTarget(class'Pawn', BestAim, BestDist, Aim, StartTrace, LockRange); 
			if ( TA != None && CanLockOnTo(TA) )
			{
				BestTarget = TA;
			}
		}
		else    // We hit a valid target
		{
			BestTarget = HitActor;
		}
	}

	// If we have a "possible" target, note its time mark
	if ( BestTarget != None )
	{
		LastValidTargetTime = WorldInfo.TimeSeconds;

		if ( BestTarget == LockedTarget )
		{
			LastLockedOnTime = WorldInfo.TimeSeconds;
		}
		else
		{
			if ( LockedTarget != None && ((WorldInfo.TimeSeconds - LastLockedOnTime > LockTolerance) || !CanLockOnTo(LockedTarget)) )
			{
				// Invalidate the current locked Target
				AdjustLockTarget(None);
			}

			// We have our best target, see if they should become our current target.
			// Check for a new Pending Lock
			if (PendingLockedTarget != BestTarget)
			{
				PendingLockedTarget = BestTarget;
				PendingLockedTargetTime = ((Vehicle(PendingLockedTarget) != None) && (UDKPlayerController(Instigator.Controller) != None) && UDKPlayerController(Instigator.Controller).bConsolePlayer)
										? WorldInfo.TimeSeconds + 0.5*LockAcquireTime
										: WorldInfo.TimeSeconds + LockAcquireTime;
			}

			// Otherwise check to see if we have been tracking the pending lock long enough
			else if (PendingLockedTarget == BestTarget && WorldInfo.TimeSeconds >= PendingLockedTargetTime )
			{
				AdjustLockTarget(PendingLockedTarget);
				LastLockedOnTime = WorldInfo.TimeSeconds;
				PendingLockedTarget = None;
				PendingLockedTargetTime = 0.0;
			}
		}
	}
	else 
	{
		if ( LockedTarget != None && ((WorldInfo.TimeSeconds - LastLockedOnTime > LockTolerance) || !CanLockOnTo(LockedTarget)) )
		{
			// Invalidate the current locked Target
			AdjustLockTarget(None);
		}

		// Next attempt to invalidate the Pending Target
		if ( PendingLockedTarget != None && ((WorldInfo.TimeSeconds - LastValidTargetTime > LockTolerance) || !CanLockOnTo(PendingLockedTarget)) )
		{
			PendingLockedTarget = None;
		}
	}
}

auto simulated state Inactive
{
	ignores Tick;

	simulated function BeginState(name PreviousStateName)
	{
		Super.BeginState(PreviousStateName);

		if ( Role == ROLE_Authority )
		{
			bTargetLockingActive = false;
			AdjustLockTarget(None);
		}
	}

	simulated function EndState(Name NextStateName)
	{
		Super.EndState(NextStateName);

		if ( Role == ROLE_Authority )
		{
			bTargetLockingActive = true;
		}
	}
}

simulated event Destroyed()
{
	AdjustLockTarget(none);
	super.Destroyed();
}

/**
 * If we are locked on, we need to set the Seeking projectiles LockedTarget.
 */

simulated function Projectile ProjectileFire()
{
	local Projectile SpawnedProjectile;

	SpawnedProjectile = super.ProjectileFire();
    if (bLockedOnTarget && Rx_Projectile_Rocket(SpawnedProjectile) != None)
    {
       Rx_Projectile_Rocket(SpawnedProjectile).FinalSeekTarget = LockedTarget;
       Rx_Projectile_Rocket(SpawnedProjectile).GotoState('Homing');
    }  

	return SpawnedProjectile;
}

simulated function Projectile ProjectileFireOld()
{
	local Projectile SpawnedProjectile;

	SpawnedProjectile = super.ProjectileFireOld();
    
	
	if (bLockedOnTarget && Rx_Projectile_Rocket(SpawnedProjectile) != None)
    {
		if(Rx_Projectile_Rocket(SpawnedProjectile).RocketStages.Length > 0 &&  Rx_Projectile_Rocket(SpawnedProjectile).RocketStages[0].bIgnoreHoming )
		{
			Rx_Projectile_Rocket(SpawnedProjectile).FinalSeekTarget = LockedTarget;
		}
		else
			Rx_Projectile_Rocket(SpawnedProjectile).SeekTarget = LockedTarget;
	   //Rx_Projectile_Rocket(SpawnedProjectile).Target = LockedTarget.GetTargetLocation();
       Rx_Projectile_Rocket(SpawnedProjectile).GotoState('Homing');
    }
	

	return SpawnedProjectile;
}

/**
 * We override GetProjectileClass to swap in a Seeking Rocket if we are locked on.
 */
function class<Projectile> GetProjectileClass()
{
	if (bLockedOnTarget)
	{
		return SeekingRocketClass;
	}
	else
	{
		return WeaponProjectiles[CurrentFireMode];
	}
}

simulated function ActiveRenderOverlays( HUD H )
{
   local PlayerController PC;
   PC = PlayerController(Instigator.Controller);
   
   if ( bLockedOnTarget && (LockedTarget != None) && (Instigator != None) && WorldInfo.NetMode != NM_DedicatedServer) {
      if ( ((LocalPlayer(PC.Player) == None) || !LocalPlayer(PC.Player).GetActorVisibility(LockedTarget))) {
          DrawCrosshair(H);
          return;
      }
      else {
         DrawLockedOn( H );
      }
   }
   else {
   	  DrawCrosshair(H);
      bWasLocked = false;
   }
}

simulated function DrawCrosshair( Hud HUD )
{
	local float x,y;
	local UTHUDBase H;
	local Pawn MyPawnOwner;
	local actor TargetActor;
	local int targetTeam;
	local LinearColor LC, LockColor; //nBab
	local vector ScreenLoc;
	local bool bTargetBehindUs;
	local float XResScale, MinDotScale;
	
	
	//set initial color based on settings (nBab)
	LC.A = 1.f;
	switch (Rx_HUD(Rx_Controller(Instigator.Controller).myHUD).SystemSettingsHandler.GetCrosshairColor())
	{
		//white
		case 0:
			LC.R = 1.f;
			LC.G = 1.f;
			LC.B = 1.f;
			break;
		//orange
		case 1:
			LC.R = 2.f;
			LC.G = 0.5f;
			LC.B = 0.f;
			break;
		//violet
		case 2:
			LC.R = 2.f;
			LC.G = 0.f;
			LC.B = 2.f;
			break;
		//blue
		case 3:
			LC.R = 0.f;
			LC.G = 0.f;
			LC.B = 2.f;
			break;
		//cyan
		case 4:
			LC.R = 0.f;
			LC.G = 2.f;
			LC.B = 2.f;
			break;	
	}	

	H = UTHUDBase(HUD);
	if ( H == None )
		return;
		
	XResScale = H.Canvas.SizeX/1920.0;
	MinDotScale = Fmax(XResScale, 0.73);
		
	CrosshairWidth = (default.CrosshairWidth + RecoilSpread*RecoilSpreadCrosshairScaling) * XResScale;	
	CrosshairHeight = (default.CrosshairHeight + RecoilSpread*RecoilSpreadCrosshairScaling) * XResScale;
		
	CrosshairLinesX = H.Canvas.ClipX * 0.5 - (CrosshairWidth * 0.5);
	CrosshairLinesY = H.Canvas.ClipY * 0.5 - (CrosshairHeight * 0.5);	
	
	MyPawnOwner = Pawn(Owner);

	//determines what we are looking at and what color we should use based on that.
	if (MyPawnOwner != None)
	{
		TargetActor = Rx_Hud(HUD).GetActorWeaponIsAimingAt();
		if (Pawn(TargetActor) == None && Rx_Weapon_DeployedActor(TargetActor) == None && 
			Rx_Building(TargetActor) == None && Rx_BuildingAttachment(TargetActor) == None)
		{
			TargetActor = (TargetActor == None) ? None : Pawn(TargetActor.Base);
		}
		
		if(TargetActor != None)
		{
			targetTeam = TargetActor.GetTeamNum();
			
			if (targetTeam == 0 || targetTeam == 1) //has to be gdi or nod player
			{
				if (targetTeam != MyPawnOwner.GetTeamNum())
				{
					if (!TargetActor.IsInState('Stealthed') && !TargetActor.IsInState('BeenShot'))
					{
						//enemy, go red, except if stealthed (else would be cheating ;] )
						//nBab
						LC.R = 10.f;
						LC.G = 0.f;
						LC.B = 0.f;
					}
				}
				else
				{
					//Friendly
					//nBab
					LC.R = 0.f;
					LC.G = 10.f;
					LC.B = 0.f;
				}
			}
		}
	}
	
	if (!HasAnyAmmo()) //no ammo, go yellow
	{
		//nBab
		LC.R = 10.f;
		LC.G = 8.f;
		LC.B = 0.f;
	}
	else
	{
		if (CurrentlyReloading || CurrentlyBoltReloading || (BoltActionReload && HasAmmo(CurrentFireMode) && IsTimerActive('BoltActionReloadTimer'))) //reloading, go yellow
		{
			//nBab
			LC.R = 10.f;
			LC.G = 8.f;
			LC.B = 0.f;
		}

	}

	//nBab
	CrosshairMIC2.SetVectorParameterValue('Reticle_Colour', LC);
	CrosshairDotMIC2.SetVectorParameterValue('Reticle_Colour', LC);
	
	H.Canvas.SetPos( CrosshairLinesX, CrosshairLinesY );
	if(bDisplayCrosshair) {
		H.Canvas.DrawMaterialTile(CrosshairMIC2, CrosshairWidth, CrosshairHeight);
		
		if(PendingLockedTarget != none)
			{
				bTargetBehindUs = class'Rx_Utils'.static.OrientationOfLocAndRotToBLocation(Rx_Controller(Instigator.Controller).ViewTarget.Location,Instigator.Controller.Rotation,PendingLockedTarget.location) < -0.5;
				
					if(!bTargetBehindUs)
					{
					LockColor.R = 1.f;
					LockColor.G = 10.f;
					LockColor.B = 1.f;
					CrosshairMIC2.SetVectorParameterValue('Reticle_Colour', LockColor);
					ScreenLoc = PendingLockedTarget.location; 
					ScreenLoc = H.Canvas.Project(ScreenLoc);
					H.Canvas.SetPos( ScreenLoc.X - CrosshairWidth/2, ScreenLoc.Y - CrosshairWidth/2 );
					H.Canvas.DrawMaterialTile(CrosshairMIC2, CrosshairWidth, CrosshairHeight);
					}
				}
				
		
	}

	CrosshairLinesX = H.Canvas.ClipX * 0.5 - (default.CrosshairWidth * 0.5 * MinDotScale);
	CrosshairLinesY = H.Canvas.ClipY * 0.5 - (default.CrosshairHeight * 0.5 * MinDotScale);
	GetCrosshairDotLoc(x, y, H);
	H.Canvas.SetPos( X, Y );
	if(bDisplayCrosshair) {
		H.Canvas.DrawMaterialTile(CrosshairDotMIC2, default.CrosshairWidth*MinDotScale, default.CrosshairHeight*MinDotScale);
		
	}
	DrawHitIndicator(H,x,y);
	
}

simulated function bool UsesClientSideProjectiles(byte FireMode)
{
	return FireMode==1;
}


DefaultProperties
{
	// Weapon SkeletalMesh
	Begin Object class=AnimNodeSequence Name=MeshSequenceA
	End Object

	// Weapon SkeletalMesh
	Begin Object Name=FirstPersonMesh
		SkeletalMesh=SkeletalMesh'RX_WP_MissileLauncher.Meshes.SK_WP_MissileLauncher_1P'
		AnimSets(0)=AnimSet'RX_WP_MissileLauncher.Anims.AS_MissileLauncher_Weapon'
		Animations=MeshSequenceA
		Scale=2.0
		FOV=55.0
	End Object

	// Weapon SkeletalMesh
	Begin Object Name=PickupMesh
		SkeletalMesh=SkeletalMesh'RX_WP_MissileLauncher.Meshes.SK_WP_MissileLauncher_Back'
		//Translation=(X=-25)
		Scale=1.0
	End Object
	
	ArmsAnimSet = AnimSet'RX_WP_MissileLauncher.Anims.AS_MissileLauncher_Arms'

	AttachmentClass = class'Rx_Attachment_MissileLauncher'
	
	PlayerViewOffset=(X=0.0,Y=0.0,Z=-1.5)
	WideScreenOffsetScaling = 0.0
	BobDamping = 0.85
	JumpDamping = 0.5

	FireOffset=(X=20,Y=10,Z=-3)
	
	LeftHandIK_Offset=(X=-3.054600,Y=-3.855900,Z=0.031600)
	LeftHandIK_Rotation=(Pitch=910,Yaw=2002,Roll=-1092)
	RightHandIK_Offset=(X=4.0,Y=-2.0,Z=2.0)
	
	LeftHandIK_Relaxed_Offset = (X=-4.000000,Y=-4.000000,Z=-1.000000)
	LeftHandIK_Relaxed_Rotation = (Pitch=0,Yaw=0,Roll=3640)
	RightHandIK_Relaxed_Offset = (X=0.000000,Y=-5.000000,Z=-8.000000)
	RightHandIK_Relaxed_Rotation = (Pitch=-5461,Yaw=6189,Roll=14017)
	
	bOverrideLeftHandAnim=true
	LeftHandAnim=H_M_Hands_Closed
	
	//-------------- Recoil
	RecoilDelay = 0.07
	RecoilSpreadDecreaseDelay = 0.1
	MinRecoil = 1000.0
	MaxRecoil = 1200.0
	MaxTotalRecoil = 5000.0
	RecoilYawModifier = 0.75 // will be a random value between 0 and this value for every shot
	RecoilInterpSpeed = 60.0
	RecoilDeclinePct = 0.75
	RecoilDeclineSpeed = 4.0
	RecoilSpread = 0.0
	MaxSpread = 0.1
	RecoilSpreadIncreasePerShot = 0.0
	RecoilSpreadDeclineSpeed = 0.03

	ShotCost(0)=1
	ShotCost(1)=1
	FireInterval(0)=+0.4
	FireInterval(1)=+0.4
	ReloadTime(0) = 3.2
	ReloadTime(1) = 3.2
	
	EquipTime=0.75
	PutDownTime=0.5

	WeaponFireTypes(0)=EWFT_Projectile
	WeaponFireTypes(1)=EWFT_Projectile
	
	WeaponProjectiles(0)=class'Rx_Projectile_MissileLauncher'
	WeaponProjectiles(1)=class'Rx_Projectile_MissileLauncherAlt'

	WeaponProjectiles_Heroic(0)=class'Rx_Projectile_MissileLauncher_Heroic'
	WeaponProjectiles_Heroic(1)=class'Rx_Projectile_MissileLauncherAlt_Heroic'
	
	Spread(0)=0.0
	Spread(1)=0.0
	
	ClipSize = 1
	InitalNumClips = 26
	MaxClips = 26

	ReloadAnimName(0) = "weaponreload"
	ReloadAnimName(1) = "weaponreload"
	ReloadAnim3PName(0) = "H_M_RocketLauncher_Reload"
	ReloadAnim3PName(1) = "H_M_RocketLauncher_Reload"
	ReloadArmAnimName(0) = "weaponreload"
	ReloadArmAnimName(1) = "weaponreload"

	WeaponFireSnd[0]=SoundCue'RX_WP_MissileLauncher.Sounds.SC_MissileLauncher_Fire'
	WeaponFireSnd[1]=SoundCue'RX_WP_MissileLauncher.Sounds.SC_MissileLauncher_Fire'
	
	WeaponDistantFireSnd=SoundCue'RX_WP_RocketLauncher.Sounds.SC_RocketLauncher_DistantFire'

	WeaponPutDownSnd=SoundCue'RX_WP_MissileLauncher.Sounds.SC_MissileLauncher_PutDown'
	WeaponEquipSnd=SoundCue'RX_WP_MissileLauncher.Sounds.SC_MissileLauncher_Equip'
	ReloadSound(0)=SoundCue'RX_WP_MissileLauncher.Sounds.SC_MissileLauncher_Reload'
	ReloadSound(1)=SoundCue'RX_WP_MissileLauncher.Sounds.SC_MissileLauncher_Reload'
	
	

	PickupSound=SoundCue'A_Pickups.Weapons.Cue.A_Pickup_Weapons_Link_Cue'

	MuzzleFlashSocket="MuzzleFlashSocket"
	FireSocket = "MuzzleFlashSocket"
	MuzzleFlashPSCTemplate=ParticleSystem'RX_WP_MissileLauncher.Effects.P_MuzzleFlash'
	MuzzleFlashDuration=3.3667
	MuzzleFlashLightClass=class'RenX_Game.Rx_Light_AutoRifle_MuzzleFlash'

	CrosshairMIC = MaterialInstanceConstant'RenXHud.MI_Reticle_RocketLauncher'
	LockedOnCrosshairMIC = MaterialInstanceConstant'RenX_AssetBase.UI.MI_Reticle_MissileLock'

	InventoryGroup=2
	InventoryMovieGroup=16

	WeaponIconTexture=Texture2D'RX_WP_MissileLauncher.UI.T_WeaponIcon_MissileLauncher'
	
	// AI Hints:
	// MaxDesireability=0.7
	AIRating=+0.4
	CurrentRating=+0.4
	bFastRepeater=false
	bInstantHit=false
	bSplashJump=false
	bRecommendSplashDamage=true
	bSniping=false  
	bOkAgainstBuildings=true
	bOkAgainstVehicles=true 

	//==========================================
	// LOCKING PROPERTIES
	//==========================================
	LockAcquiredSound=SoundCue'A_Weapon_RocketLauncher.Cue.A_Weapon_RL_SeekLock_Cue'
	LockLostSound=SoundCue'A_Weapon_RocketLauncher.Cue.A_Weapon_RL_SeekLost_Cue'

	SeekingRocketClass=class'Rx_Projectile_MissileLauncher'

	ConsoleLockAim=0.99
	LockRange=7500
	LockAim=0.99//0.999999
	LockChecktime=0.25
	LockAcquireTime=1.25//0.75
	LockTolerance=1.5 //3.0   
    bTargetLockingActive = true

	//==========================================
	// IRON SIGHT PROPERTIES
	//==========================================
	
	// IronSight:
	bIronSightCapable = false	
	bDisplayCrosshairInIronsight = true
	IronSightViewOffset=(X=-8,Y=0,Z=3)
	IronSightFireOffset=(X=20,Y=7,Z=0)
	IronSightBobDamping=1
	IronSightPostAnimDurationModifier=1.0
	// This sets how much we want to zoom in, this is a value to be subtracted because smaller FOV values are greater levels of zoom
	ZoomedFOVSub=35.0 
	// New lower speed movement values for use while zoom aiming
	ZoomGroundSpeed=100
	ZoomAirSpeed=340.0
	ZoomWaterSpeed=11
	
	// IronSight additional vars to the vars in AimingWeaponClass (1 means unchanged, higher values mean more dmaping):
	IronSightMinRecoilDamping = 2
	IronSightMaxRecoilDamping = 2
	IronSightMaxTotalRecoilDamping = 2
	IronSightRecoilYawDamping = 1
	IronSightMaxSpreadDamping = 2
	IronSightSpreadIncreasePerShotDamping = 4

	/** one1: Added. */
	BackWeaponAttachmentClass = class'Rx_BackWeaponAttachment_MissileLauncher'
	
	
	/*******************/
	/*Veterancy*/
	/******************/

	Vet_ReloadSpeedModifier(0)=1 //Normal (should be 1)
	Vet_ReloadSpeedModifier(1)=0.95 //Veteran 
	Vet_ReloadSpeedModifier(2)=0.9 //Elite
	Vet_ReloadSpeedModifier(3)=0.80 //Heroic
	/**********************/
	//17 > 12 
	Elite_Building_DamageMod = 1.33 //1.75 //Increase building damage at Elite 
	Ammo_Increment = 4
}
