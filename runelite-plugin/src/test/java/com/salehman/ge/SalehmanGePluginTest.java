package com.salehman.ge;

import net.runelite.client.RuneLite;
import net.runelite.client.externalplugins.ExternalPluginManager;

/**
 * Local DEV preview launcher (NOT a unit test). Side-loads the plugin via
 * loadBuiltin and starts RuneLite from source — use this to preview code
 * changes quickly:  ./gradlew runClient
 *
 * NOTE: a source/gradle run does NOT scan ~/.runelite/sideloaded-plugins, so
 * the INSTALLED plugin (for your normal plugin list) only shows up in the
 * official RuneLite client. See install-plugin.sh.
 */
public class SalehmanGePluginTest
{
	public static void main(String[] args) throws Exception
	{
		ExternalPluginManager.loadBuiltin(SalehmanGePlugin.class);
		RuneLite.main(args);
	}
}
