/*
 * generated by Xtext 2.27.0
 */
package de.fraunhofer.ipa.deployment;


/**
 * Initialization support for running Xtext languages without Equinox extension registry.
 */
public class DeployModelStandaloneSetup extends DeployModelStandaloneSetupGenerated {

	public static void doSetup() {
		new DeployModelStandaloneSetup().createInjectorAndDoEMFRegistration();
	}
}
