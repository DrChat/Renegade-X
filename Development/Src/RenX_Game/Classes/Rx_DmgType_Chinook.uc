class Rx_DmgType_Chinook extends Rx_DmgType_Bullet;

defaultproperties
{
    KillStatsName=KILLS_CHINOOK
    DeathStatsName=DEATHS_CHINOOK
    SuicideStatsName=SUICIDES_CHINOOK

    DamageWeaponFireMode=2
    VehicleDamageScaling=0.17
    NodeDamageScaling=0.5
    VehicleMomentumScaling=0.1
    
	bBulletHit=True

    CustomTauntIndex=10
    lightArmorDmgScaling=0.17
    BuildingDamageScaling=0.34
	MCTDamageScaling=3.0
	MineDamageScaling=2.0
	
    AlwaysGibDamageThreshold=19
	bNeverGibs=false
	
	KDamageImpulse=8000
	KDeathUpKick=200

	IconTextureName="T_DeathIcon_Chinook"
	IconTexture=Texture2D'RX_VH_Chinook.UI.T_DeathIcon_Chinook'
}