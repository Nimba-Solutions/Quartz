/**
* @File Name : AccountTrigger.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : January 28, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | January 28, 2025 |   | Initial Version
**/

public class AccountTrigger {
	@AuraEnabled
	public static void LightningStudio(){
		System.debug('Lightning Studio');
	}
}