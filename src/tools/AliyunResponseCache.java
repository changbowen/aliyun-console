package tools;
import com.aliyuncs.AcsRequest;
import com.aliyuncs.AcsResponse;
import com.aliyuncs.RpcAcsRequest;
import com.aliyuncs.exceptions.ClientException;
import com.sun.istack.NotNull;
import tools.AliyunApiWrappers.*;
import com.aliyuncs.DefaultAcsClient;

import java.io.*;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.nio.file.attribute.FileTime;
import java.time.Instant;
import java.util.*;

import com.esotericsoftware.kryo.Kryo;
import com.esotericsoftware.kryo.io.Output;
import com.esotericsoftware.kryo.io.Input;

public class AliyunResponseCache
{
    public static int cache_expires = 86400;
    public static String inst_cache_dir = Util.AppRootDir + "cached_instances/";
    public static String resp_cache_dir = Util.AppRootDir + "cached_responses/";


    /**
     * Used to load or save request and the corresponding response to disk.
     * If cache is skipped due to missing, expiration or false $tryCache, cache will still be updated.
     * With this request-to-response caching method it would be hard to update only part of the cache.
     * Currently only used for getting prices.
     * @param tryCache Whether to try cache first or directly send request to server.
     * @return mixed|null|SimpleXMLElement Cached or live response
     */
    public static <T extends com.aliyuncs.AcsResponse> T
    GetResponse(DefaultAcsClient client, @NotNull AcsRequest<T> req, boolean tryCache) throws IOException, ClientException
    {
        T resp = null;
        var cacheFile = resp_cache_dir + Util.getMD5(req);

        if (!tryCache || IsMissingOrExpired(cacheFile))
        {
            resp = client.getAcsResponse(req);
            Files.createDirectories(Paths.get(resp_cache_dir));
            KryoSave(cacheFile, resp);
        }
        else
            resp = (T)KryoLoad(cacheFile);

        return resp;
    }
    public static <T extends com.aliyuncs.AcsResponse> T
    GetResponse(DefaultAcsClient client, @NotNull AcsRequest<T> req) throws IOException, ClientException {
        return GetResponse(client, req, true);
    }


    /**
     * Check whether the cache file specified is missing or expired. The cache file will be deleted when found expired.
     * @param cacheFile The path to the cache file.
     * @param expireSec Cache lifespan in seconds.
     * @return False if the cache is still valid. True when the cache file is missing or expired.
     */
    public static boolean IsMissingOrExpired(String cacheFile, int expireSec) throws IOException
    {
        var path = Paths.get(cacheFile);
        if (!Files.exists(path)) return true;

        if (Instant.now().plusSeconds(-expireSec).isAfter(((FileTime)Files.getAttribute(path, "creationTime")).toInstant()))
        {
            Files.delete(path);//delete cache file when expired
            return true;
        }
        return false;
    }
    /**
     * Check whether the cache file specified is missing or expired with the default threshold (1 day).
     * The cache file will be deleted when found expired.
     */
    public static boolean IsMissingOrExpired(String cacheFile) throws IOException {
        return IsMissingOrExpired(cacheFile, cache_expires);
    }


    /**
     * @param filter Map with parameter name and value to look for from the cache. Value can be an array.
     * @return Returns Map that contains the content of the cache.
     * If the cache is invalid (file does not exist or has expired), returns null.
     * If no match is found based on filter, returns an empty Map.
     */
    public static HashMap<String, ?> LoadInstFromCache(String region, RequestTypes reqType, Map<String, ?> filter)
            throws IOException
    {
        var cacheFile = inst_cache_dir + region + "~" + reqType;

        //return null when file does not exist, or has expired
        if (IsMissingOrExpired(cacheFile)) return null;

        //read cache to memory
        var cacheContent = (HashMap<String, ?>)KryoLoad(cacheFile);

        //return param-specified instance if available. Otherwise the whole cache
        if (filter != null && filter.size() > 0)
        {
            var filteredCache = new HashMap<String, Object>();
            for (var m : cacheContent.entrySet())
            {
                var mVal = m.getValue();
                //look for instances with specified parameter name and values
                var hit = 0;
                for (var p : filter.entrySet()) {
                    var pKey = p.getKey();//"InstanceId"
                    var pVal = p.getValue();//["i-2zebqngpatbxy905xl2e", "i-2zeb62gfds6t9pzkgtxf"]
                    try
                    {
                        if (pVal instanceof Object[])
                        {
                            for (var _pVal : (Object[])pVal)//_pVal: "i-2zebqngpatbxy905xl2e"
                            {
                                if (Util.getSomething(mVal, pKey).equals(_pVal)) { hit++; break; }
                            }
                        }
                        else
                        {
                            //inst.getInstanceId() == i-2zebqngpatbxy905xl2e
                            if (Util.getSomething(mVal, pKey).equals(pVal)) hit++;
                        }
                    }
                    catch (Exception ex) { }
                }
                //considered match when all filter items are found inside an entry (mVal)
                if (hit == filter.size()) filteredCache.put(m.getKey(), m.getValue());
            }
            //when nothing is found, return empty array instead of null
            return filteredCache;
        }
        else
            return cacheContent;
    }
    public static HashMap<String, ?> LoadInstFromCache(String region, RequestTypes reqType)
            throws IOException {
        return LoadInstFromCache(region, reqType, null);
    }

    /**
     * Write instArray to disk. If cache exists, update it with instArray (even if it is already invalid).
     */
    public static void WriteInstToCache(String region, AliyunApiWrappers.RequestTypes reqType, Map<String, ?> instArray)
            throws IOException
    {
        //check and create directory if needed
        Files.createDirectories(Paths.get(inst_cache_dir));

        var cacheFile = inst_cache_dir + region + "~" + reqType;
        var file = new File(cacheFile);
        var kryo = new Kryo();
        if (file.exists())
        {
            var existInst = (Map<String, Object>)KryoLoad(kryo, file);
            existInst.putAll(instArray);
            KryoSave(kryo, file, existInst);
        }
        else
            KryoSave(kryo, file, instArray);
    }


    private static Object KryoLoad(Kryo kryo, File file) throws FileNotFoundException {
        Object map;
        try (var strmIn = new Input(new FileInputStream(file))) {
            map = kryo.readClassAndObject(strmIn);
        }
        return map;
    }
    private static Object KryoLoad(File file) throws FileNotFoundException {
        return KryoLoad(new Kryo(), file);
    }
    private static Object KryoLoad(String file) throws FileNotFoundException {
        return KryoLoad(new Kryo(), new File(file));
    }


    private static void KryoSave(Kryo kryo, File file, Object obj) throws FileNotFoundException {
        try (var strmOut = new Output(new FileOutputStream(file))) {
            kryo.writeClassAndObject(strmOut, obj);
        }
    }
    private static void KryoSave(File file, Object obj) throws FileNotFoundException {
        KryoSave(new Kryo(), file, obj);
    }
    private static void KryoSave(String file, Object obj) throws FileNotFoundException {
        KryoSave(new Kryo(), new File(file), obj);
    }
}
