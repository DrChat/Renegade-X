/*********************************************************
*
* File: Rx_Building_TechbuildingPoint.uc
* Author: RenegadeX-Team
* Pojekt: Renegade-X UDK <www.renegade-x.com>
*
* Desc:
* Base class for tech building utilizing Rx_CapturePoint. The internals class spawn the Rx_CapturePoint
* 
* 
* See Also :
* - Rx_Volume_CaptureArea - Use this as override to Cylinder Collision method
* - Rx_Building_TechBuildingPoint_Internals - The internal of this building. This is the class that both spawns the Rx_CapturePoint and is linked to it.
*
*********************************************************
*  
*********************************************************/

class Rx_Building_TechbuildingPoint extends Rx_Building_Techbuilding;

var(PointCapture) float CaptureRadius;
var(PointCapture) float CaptureHeight;


var(PointCapture) Rx_Volume_CaptureArea CaptureVolume; // if assigned, CapturePoint will NOT use the original proximity-based capturing and instead calculates player depending on whether or not they're in the volume
var(PointCapture) class<Rx_CapturePoint_TechBuilding> CapturePointClass;

DefaultProperties
{
	CapturePointClass = class'Rx_CapturePoint_TechBuilding'
	BuildingInternalsClass = class'Rx_Building_TechBuildingPoint_Internals'
	CaptureRadius = 512.f
	CaptureHeight = 256.f
}