public with sharing class UnsplashService {
    private static final String ACCESS_KEY = '0VaezWhktWP_XPc7sw3udlp5aL-s91zINVNKIoO47FM';  // Replace with your real key
    private static final String BASE_URL = 'https://api.unsplash.com/search/photos';

    @AuraEnabled
    public static String getImageUrl(String query) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(BASE_URL + '?query=' + EncodingUtil.urlEncode(query, 'UTF-8') + '&per_page=1');
        req.setMethod('GET');
        req.setHeader('Authorization', 'Client-ID ' + ACCESS_KEY);

        Http http = new Http();
        HttpResponse res = http.send(req);
        if (res.getStatusCode() == 200) {
            Map<String, Object> body = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
            List<Object> results = (List<Object>)body.get('results');
            if (results != null && !results.isEmpty()) {
                Map<String, Object> first = (Map<String, Object>)results[0];
                Map<String, Object> urls = (Map<String, Object>)first.get('urls');
                return (String)urls.get('regular');
            }
        }
        return null;
    }
}