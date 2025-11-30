first install curl-devel
#su
#yum install curl-devel

reference from
http://luacurl.luaforge.net/
https://github.com/arcapos/luacurl

LuaCURL is Lua 5.x compatible module providing Internet browsing capabilities based on the CURL library. The module interface follows strictly the CURl architecture and is very easy to use if the programmer has already experience with CURL. The only LuaCURL luaopen_luacurl public function register itself to the Lua context defining a namespace curl with one constructor and some utility functions.
Registration

There are different ways to register LuaCURL to Lua as dynamically loaded module. But in all cases your Lua program have to be configured to support dynamic modules. If you are compiling Lua from source then make sure that LOADLIB directive is set in the lua/config file. If you are using Lua 5.0 with compat-5.1 or your Lua version is Lua 5.1 then you can use
require("luacurl")
otherwise you can use the function loadlib
curl=assert(loadlib("[lib]luacurl[.so|.dll]", "luaopen_luacurl"))()
After the luaCURL is successfully registered to the Lua context you are ready to construct curl objects and call curl functions
Functions

curl.escape(string)

Escapes URL strings
Example:
print(curl.escape("abcd$%^&*()"))
abcd%24%25%5E%26%2A%28%29
curl.unescape(string)

Unescapes URL encoding in strings
Example:
print(curl.unescape("abcd%24%25%5E%26%2A%28%29"));
abcd$%^&*()
Constructor

curl.new()

Use this function to instantiate curl objects.
Example:
c = curl.new()
Methods

c:setopt(option, value)

Set option value to a curl object c. The first parameter option is a number representing the option which can be on of the following listed below. A predefined constant curl.OPT_XXXX corresponds to CURLOPT_XXXX constant defined in the libcurl interface curl/curl.h The accepted value type depends of the corresponding option. Below are listed all curl options supported by libCURL grouped by value type. For a complete documentation on the options below read the curl manual.
Callback options

curl.OPT_READFUNCTION, function(userparam, size) -> string
curl.OPT_READDATA, userparam

curl.OPT_WRITEFUNCTION, function(userparam, buffer) -> number
curl.OPT_WRITEDATA, userparam

curl.OPT_HEADERFUNCTION, function(userparam, buffer) -> number
curl.OPT_HEADERDATA, userparam

curl.OPT_PROGRESSFUNCTION, function(userparam, dltotal, dlnow, uptotal, upnow) -> number
curl.OPT_PROGRESSDATA, userparam

curl.OPT_IOCTLFUNCTION, function(userparam, command) -> number
curl.OPT_IOCTLDATA, userparam
String list options

curl.OPT_SOURCE_QUOTE, string, ..., string
curl.OPT_QUOTE, string, ..., string
curl.OPT_POSTQUOTE, string, ..., string
curl.OPT_TELNETOPTIONS, string, ..., string
curl.OPT_PREQUOTE, string, ..., string
curl.OPT_HTTP200ALIASES, string, ..., string
curl.OPT_SOURCE_PREQUOTE, string, ..., string
curl.OPT_SOURCE_POSTQUOTE, string, ..., string
curl.OPT_HTTPHEADER, string, ..., string
curl.OPT_HTTPPOST, string, ..., string
String options

curl.OPT_FTP_ACCOUNT, string
curl.OPT_URL, string
curl.OPT_PROXY, string
curl.OPT_USERPWD, string
curl.OPT_PROXYUSERPWD, string
curl.OPT_RANGE, string
curl.OPT_POSTFIELDS, string
curl.OPT_REFERER, string
curl.OPT_FTPPORT, string
curl.OPT_USERAGENT, string
curl.OPT_COOKIE, string
curl.OPT_SSLCERT, string
curl.OPT_SSLKEYPASSWD, string
curl.OPT_COOKIEFILE, string
curl.OPT_CUSTOMREQUEST, string
curl.OPT_WRITEINFO, string
curl.OPT_INTERFACE, string
curl.OPT_KRB4LEVEL, string
curl.OPT_CAINFO, string
curl.OPT_RANDOM_FILE, string
curl.OPT_EGDSOCKET, string
curl.OPT_COOKIEJAR, string
curl.OPT_SSL_CIPHER_LIST, string
curl.OPT_SSLCERTTYPE, string
curl.OPT_SSLKEY, string
curl.OPT_SSLKEYTYPE, string
curl.OPT_SSLENGINE, string
curl.OPT_CAPATH, string
curl.OPT_ENCODING, string
curl.OPT_NETRC_FILE, string
curl.OPT_SOURCE_USERPWD, string
curl.OPT_SOURCE_URL, string
Number options

curl.OPT_MAXREDIRS, number
curl.OPT_MAXCONNECTS, number
curl.OPT_CLOSEPOLICY, number
curl.OPT_CONNECTTIMEOUT, number
curl.OPT_SSL_VERIFYHOST, number
curl.OPT_HTTP_VERSION, number
curl.OPT_DNS_CACHE_TIMEOUT, number
curl.OPT_BUFFERSIZE, number
curl.OPT_PROXYTYPE, number
curl.OPT_HTTPAUTH, number
curl.OPT_FTPSSLAUTH, number
curl.OPT_FTP_SSL, number
curl.OPT_POSTFIELDSIZE_LARGE, number
curl.OPT_PROXYAUTH, number
curl.OPT_FTP_RESPONSE_TIMEOUT, number
curl.OPT_IPRESOLVE, number
curl.OPT_MAXFILESIZE, number
curl.OPT_INFILESIZE_LARGE, number
curl.OPT_RESUME_FROM_LARGE, number
curl.OPT_MAXFILESIZE_LARGE, number
curl.OPT_PORT, number
curl.OPT_TIMEOUT, number
curl.OPT_INFILESIZE, number
curl.OPT_LOW_SPEED_LIMIT, number
curl.OPT_LOW_SPEED_TIME, number
curl.OPT_RESUME_FROM, number
curl.OPT_SSLVERSION, number
curl.OPT_TIMECONDITION, number
curl.OPT_TIMEVALUE, number
curl.OPT_NETRC, number
curl.OPT_PROXYPORT, number
curl.OPT_POSTFIELDSIZE, number
Boolean options

curl.OPT_CRLF, boolean
curl.OPT_VERBOSE, boolean
curl.OPT_HEADER, boolean
curl.OPT_NOPROGRESS, boolean
curl.OPT_NOBODY, boolean
curl.OPT_FAILONERROR, boolean
curl.OPT_UPLOAD, boolean
curl.OPT_POST, boolean
curl.OPT_FTPLISTONLY, boolean
curl.OPT_FTPAPPEND, boolean
curl.OPT_FOLLOWLOCATION, boolean
curl.OPT_TRANSFERTEXT, boolean
curl.OPT_PUT, boolean
curl.OPT_AUTOREFERER, boolean
curl.OPT_HTTPPROXYTUNNEL, boolean
curl.OPT_TCP_NODELAY, boolean
curl.OPT_FTP_CREATE_MISSING_DIRS, boolean
curl.OPT_UNRESTRICTED_AUTH, boolean
curl.OPT_FTP_USE_EPRT, boolean
curl.OPT_NOSIGNAL, boolean
curl.OPT_COOKIESESSION, boolean
curl.OPT_SSLENGINE_DEFAULT, boolean
curl.OPT_DNS_USE_GLOBAL_CACHE, boolean
curl.OPT_SSL_VERIFYPEER, boolean
curl.OPT_FILETIME, boolean
curl.OPT_FRESH_CONNECT, boolean
curl.OPT_FORBID_REUSE, boolean
curl.OPT_FTP_USE_EPSV, boolean
curl.OPT_HTTPGET, boolean
c:perform()

Call this method to perform a file transfer after all setopt calls are made.
c:perform()
c:close()

This function closes a curl connection created by curl.net
c:close()
Constants

All enumeration types and define macros from libCURL 7.14.0 are exported in curl namespace with the following names substitutions
	CURL_XXXX -> curl.XXXX
or
	CURLXXXX -> curl.XXXX