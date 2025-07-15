public with sharing class HeadlessAgentService {
    public static String clientID;
    public static String clientSecret;
    public static String tokenEndpoint;
    public static String ApiEndPoint;
    public static String orgDomian;
    public static String agentID;

    static {
        Creds__mdt creds = Creds__mdt.getInstance('HeadlessAgent');
        clientID = creds.ClientId__c;
        clientSecret = creds.clientSecret__c;
        tokenEndpoint = creds.tokenEndpoint__c;
        ApiEndPoint = creds.ApiEndPoint__c;
        orgDomian = creds.OrgDomain__c;
        agentID = creds.agentID__c;
    }

    public static String getToken() {
        String endPoint = tokenEndpoint + '?grant_type=client_credentials&client_id=' + clientID + '&client_secret=' + clientSecret;
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endPoint);
        req.setMethod('GET');
        HttpResponse response = http.send(req);
        String responseBody = response.getBody();
        String accessToken;
        if (responseBody != null) {
            try {
                Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
                if (result.containsKey('access_token')) {
                    accessToken = (String) result.get('access_token');
                }
            } catch (Exception e) {
                System.debug('Error parsing access token: ' + e.getMessage());
            }
        }
        return accessToken;
    }

    public class SessionInfo {
        @AuraEnabled public String accessToken;
        @AuraEnabled public String sessionId;
        public SessionInfo(String accessToken, String sessionId) {
            this.accessToken = accessToken;
            this.sessionId = sessionId;
        }
    }


    
    @AuraEnabled
    public static SessionInfo getSessionInfo() {
        String accessToken = getToken();
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        String endPoint = ApiEndPoint + '/agents/' + agentID + '/sessions';
        req.setEndpoint(endPoint);
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Content-Type', 'application/json');
        req.setBody(getJSONBody());

        HttpResponse response = http.send(req);

        String responseBody = response.getBody();
        String sessionId;
        if (responseBody != null) {
            try {
                Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
                if (result.containsKey('sessionId')) {
                    sessionId = (String) result.get('sessionId');
                }
            } catch (Exception e) {
                System.debug('Error parsing sessionId: ' + e.getMessage());
            }
        }
       

        return new SessionInfo(accessToken, sessionId);
    }



    public static String getJSONBody() {
        // Generate a random GUID for the session key
        String sessionKey = String.valueOf(Crypto.getRandomLong());

        // Prepare the JSON body
        String jsonBody = '{' +
            '"externalSessionKey": "' + sessionKey + '",' +
            '"instanceConfig": {"endpoint": "' + orgDomian + '"},' +
            '"tz": "America/Los_Angeles",' +
            '"variables": [' +
                '{' +
                    '"name": "$Context.EndUserLanguage",' +
                    '"type": "Text",' +
                    '"value": "en_US"' +
                '}' +
            '],' +
            '"featureSupport": "Streaming",' +
            '"streamingCapabilities": {' +
                '"chunkTypes": ["Text"]' +
            '},' +
            '"bypassUser": true' +
        '}';

        return jsonBody;
    }

    @AuraEnabled
    public static String invokeAgent(String accessToken, String sessionId, String Message) {
        String endPoint = ApiEndPoint + '/sessions/' + sessionId + '/messages';
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endPoint);
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Content-Type', 'application/json');
        
        Long timestamp = DateTime.now().getTime();
        String jsonBody = '{' +
            '"message": {' +
                '"sequenceId": ' + timestamp + ',' +
                '"type": "Text",' +
                '"text": "' + String.escapeSingleQuotes(message) + '"' +
            '},' +
            '"variables": []' +
        '}';
        
        req.setBody(jsonBody);

        HttpResponse response = http.send(req);
        // Parse the response to extract the final message inside messages
        String responseBody = response.getBody();
        String finalMessage;
        if (responseBody != null && responseBody != '') {
            try {
                
                Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
                if (result.containsKey('messages')) {
                    List<Object> messages = (List<Object>) result.get('messages');
                    System.debug('HOLAAAA ' + messages);
                    if (!messages.isEmpty()) {
                        Map<String, Object> firstMessage = (Map<String, Object>) messages[0];
                        if (firstMessage.containsKey('message')) {
                            finalMessage = (String) firstMessage.get('message');
                        }
                    }
                }
            } catch (Exception e) {
                System.debug('Error parsing final message: ' + e.getMessage());
            }
        }
        System.debug('Final Message: ' + finalMessage);
        return finalMessage;
    }








}

// Debugging the code
//System.debug('TheSessionInfo is   ' + HeadlessAgentService.getSessionInfo());