# ao-ssl-countdown
Telegraf script and AOps Symptom automation via API calls to AOps.

Basic steps for use :

	1. Install telegraf onto linux box via AOps.
	2. Upload any-ssl-check bash script to /opt/vmware.
	3. Chown arcuser/arcgroup for the script.
	4. Ensure you have a populated CSV with the endpoint details you need (host/url,port).
	5. On a system with access to Aops execute the Aops_SSL-monitoring_symptoms.ps1 filling in the following settings. (adjust code to use variables in place of prompts as you see fit)

- username/password with API POST permissions.
- authentication source for Aops (local/LDAP/vIDM etc.).
- AOps hostname (using fqdn for secure connection).
- adjust CSV location (or edit to prompt).
- name of the VM with telegraf running.

	6. Adjust Symptom warning threshold (or adjust code to prompt etc.)
	7. Check the created Symptoms in AOps, adjust any thresholds as required (<50 days etc.).
	8. If needed, Create an Alarm that is triggered with any of the Symptoms that have been created using the script above.
	
	
