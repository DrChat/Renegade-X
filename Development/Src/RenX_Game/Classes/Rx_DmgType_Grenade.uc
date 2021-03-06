class Rx_DmgType_Grenade extends Rx_DmgType_Explosive;

defaultproperties
{
    KillStatsName=KILLS_GRENADELAUNCHER
    DeathStatsName=DEATHS_GRENADELAUNCHER
    SuicideStatsName=SUICIDES_GRENADELAUNCHER

    //DamageWeaponClass=class'Rx_Weapon_GrenadeLauncher'
    DamageWeaponFireMode=0

    VehicleMomentumScaling=0.15
    VehicleDamageScaling=0.5 //0.15
    NodeDamageScaling=1.1
    bThrowRagdoll=true
    CustomTauntIndex=7
    lightArmorDmgScaling=1.0 //0.15
    BuildingDamageScaling=0.15
	MineDamageScaling=2.0
	
    AlwaysGibDamageThreshold=200
    bNeverGibs=false
	
	KDamageImpulse=10000
	KDeathUpKick=2000

	IconTextureName="T_WeaponIcon_Grenade"
	IconTexture=Texture2D'RX_WP_Grenade.UI.T_WeaponIcon_Grenade'
}