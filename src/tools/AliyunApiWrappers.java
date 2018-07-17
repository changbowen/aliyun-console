package tools;
import static tools.AliyunResponseCache.*;
import com.aliyuncs.AcsResponse;
import com.aliyuncs.DefaultAcsClient;
import com.aliyuncs.RpcAcsRequest;
import com.aliyuncs.ecs.model.v20140526.*;
import com.aliyuncs.exceptions.ClientException;
import com.aliyuncs.profile.DefaultProfile;
import com.aliyuncs.rds.model.v20140815.DescribeDBInstancesRequest;
import com.aliyuncs.rds.model.v20140815.DescribeDBInstancesResponse;
import org.w3c.dom.Element;
import org.w3c.dom.NodeList;
import org.xml.sax.SAXException;

import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.ParserConfigurationException;
import javax.xml.xpath.XPathConstants;
import javax.xml.xpath.XPathExpressionException;
import javax.xml.xpath.XPathFactory;
import java.io.File;
import java.io.IOException;
import java.lang.reflect.InvocationTargetException;
import java.util.*;
import java.util.function.BiConsumer;

public class AliyunApiWrappers
{
    static
    {
        try {
            var configFile = Util.AppRootDir + "/WEB-INF/config.xml";
            //load access keys from config file
            var doc = DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(new File(configFile));
            doc.getDocumentElement().normalize();
            var xpath = XPathFactory.newInstance().newXPath();
            var aK_ReadOnly = (Element)((NodeList) xpath.compile("//AccessKeys//AccessKey[@Type=\"Readonly\"]").evaluate(doc, XPathConstants.NODESET)).item(0);
            var aK_EcsOperator = (Element)((NodeList) xpath.compile("//AccessKeys//AccessKey[@Type=\"EcsOperator\"]").evaluate(doc, XPathConstants.NODESET)).item(0);
            AccKey_Readonly = aK_ReadOnly.getElementsByTagName("ID").item(0).getTextContent();
            AccSecret_Readonly = aK_ReadOnly.getElementsByTagName("Secret").item(0).getTextContent();
            AccKey_EcsOperator = aK_EcsOperator.getElementsByTagName("ID").item(0).getTextContent();
            AccSecret_EcsOperator = aK_EcsOperator.getElementsByTagName("Secret").item(0).getTextContent();
        }
        catch (SAXException | XPathExpressionException | ParserConfigurationException | IOException e) {
            throw new ExceptionInInitializerError(e);
        }
    }
    private static final int pageSize = 50;

    public enum RequestTypes
    {
        Ecs, Vpc, Vswitch, SecurityGroup, Disk, RouterInterface, Vrouter, Rds
    }

    private static String AccKey_EcsOperator;
    private static String AccSecret_EcsOperator;
    private static String AccKey_Readonly;
    private static String AccSecret_Readonly;

    private static DefaultAcsClient getAcsClient(String region, String key, String secret)
    {
        return new DefaultAcsClient(DefaultProfile.getProfile(region, key, secret));
    }

    public static AcsResponse InstanceStart(String region, String instanceId) throws ClientException {
        var client = getAcsClient(region, AccKey_EcsOperator, AccSecret_EcsOperator);
        var req = new StartInstanceRequest();
        req.setInstanceId(instanceId);
        return client.getAcsResponse(req);
    }

    public static AcsResponse InstanceStop(String region, String instanceId) throws ClientException {
        var client = getAcsClient(region, AccKey_EcsOperator, AccSecret_EcsOperator);
        var req = new StopInstanceRequest();
        req.setInstanceId(instanceId);
        return client.getAcsResponse(req);
    }

    public static HashMap<String, ?> GetInstances(String region, RequestTypes reqType) throws Exception {
        return GetInstances(region, reqType, null, true, null);
    }
    public static HashMap<String, ?> GetInstances(String region, RequestTypes reqType, Map<String, ?> reqParams) throws Exception {
        return GetInstances(region, reqType, reqParams, true, null);
    }
    public static HashMap<String, ?> GetInstances(String region, RequestTypes reqType, boolean cache) throws Exception {
        return GetInstances(region, reqType, null, cache, null);
    }
    /**
     * Please note reqParams and cacheFilter are not necessarily the same.
     * If cache is true and reqParams is set, cacheFilter needs also to be set correctly in order to get consistent results.
     * cacheFilter is applied locally to results returned from cache.
     * Key is prepended with "get" and then called with reflection.
     * Value is compared directly with the result of the reflection call; Or if it is an array, looped through until a match is found.
     * @param reqParams Parameters will be used like $req->setKey(Value).
     *                  When cache is invalid and reqParams are set, cache may be refreshed with incomplete results.
     * @param cache True to use cache when possible. False to ignore cache and update cache afterwards.
     * @param cacheFilter Map to filter cache based on key and value. Only useful when $cache is set to true.
     * @return Return all instances of given request type and parameters within a region.
     */
    public static HashMap<String, ?> GetInstances(String region,
                                                  RequestTypes reqType,
                                                  Map<String, ?> reqParams,
                                                  boolean cache,
                                                  Map<String, ?> cacheFilter)
            throws NoSuchMethodException, IllegalAccessException, InvocationTargetException, IOException, ClientException

    {
        //load from cache. when fails, get response and write to cache
        HashMap<String, ?> cachedResp = null;
        boolean cacheValid;

        if (cache) {
            cachedResp = LoadInstFromCache(region, reqType, cacheFilter);
            //use cache only when cache is valid. cachedResp can be null.
            //if (cachedResp != null && cachedResp.size() > 0) return cachedResp;
            if (cachedResp != null) return cachedResp; else cacheValid = false;
        }
        else//when cache is false, need to get the validity of cache for the warning later.
            cacheValid = !IsMissingOrExpired(inst_cache_dir + region + "~" + reqType);

        var client = getAcsClient(region, AccKey_Readonly, AccSecret_Readonly);
        HashMap<String, ?> result = null;

        switch (reqType)
        {
            case Ecs: {
                var req = new DescribeInstancesRequest();
                req.setPageSize(pageSize);
                req.setRegionId(region);
                setRequestParams(reqParams, req);
                result = getFromAllPages(client, req);
                break;
            }
            case Vpc: {
                var req = new DescribeVpcsRequest();
                req.setPageSize(pageSize);
                req.setRegionId(region);
                setRequestParams(reqParams, req);
                result = getFromAllPages(client, req);
                break;
            }
            case Vswitch: {
                var req = new DescribeVSwitchesRequest();
                req.setPageSize(pageSize);
                req.setRegionId(region);
                setRequestParams(reqParams, req);
                result = getFromAllPages(client, req);
                break;
            }
            case SecurityGroup: {
                var req = new DescribeSecurityGroupsRequest();
                req.setPageSize(pageSize);
                req.setRegionId(region);
                setRequestParams(reqParams, req);
                result = getFromAllPages(client, req);
                break;
            }
            case Disk: {
                var req = new DescribeDisksRequest();
                req.setPageSize(pageSize);
                req.setRegionId(region);
                setRequestParams(reqParams, req);
                result = getFromAllPages(client, req);
                break;
            }
            case RouterInterface: {
                var req = new DescribeRouterInterfacesRequest();
                req.setPageSize(pageSize);
                req.setRegionId(region);
                setRequestParams(reqParams, req);
                result = getFromAllPages(client, req);
                break;
            }
            case Vrouter: {
                var req = new DescribeVRoutersRequest();
                req.setPageSize(pageSize);
                req.setRegionId(region);
                setRequestParams(reqParams, req);
                result = getFromAllPages(client, req);
                break;
            }
            case Rds: {
                var req = new DescribeDBInstancesRequest();
                req.setPageSize(pageSize);
                req.setRegionId(region);
                setRequestParams(reqParams, req);
                result = getFromAllPages(client, req);
                break;
            }
        }

        //if the code reaches here, cachedResp is definitely null.
        //which means cache is invalid and deleted, or unknown and about to be updated.
        if (!cacheValid && reqParams != null && reqParams.size() > 0)
            System.err.println("WARNING: AliyunApiWrappers.GetInstances(): reqParams is not empty when cache is invalid, which may lead to incomplete results in cache.");

        //write to cache when either $cache is false, cache is invalid or $cacheResp is empty
        WriteInstToCache(region, reqType, result);

        return result;
    }


    /**
     * @param priceUnit Can be Month (subscription price), Year (subscription price) and Hour (pay-as-you-go price).
     *                  Month or Year on old instance types may get error response.
     * @param period According to priceUnit value, period value range is as follows. Default value is 1.
     *               Month: 1 - 9; Year: 1 - 3; Hour: 1;
     */
    public static DescribePriceResponse.PriceInfo.Price GetPrice(Object inst, String priceUnit, int period, boolean cache)
            throws InvocationTargetException, NoSuchMethodException, IOException, ClientException, IllegalAccessException
    {
        if (inst instanceof DescribeInstancesResponse.Instance) {
            var instEcs = (DescribeInstancesResponse.Instance) inst;
            var instEcsDisks = (HashMap<String, DescribeDisksResponse.Disk>) GetInstances(
                    instEcs.getRegionId(),
                    RequestTypes.Disk,
                    Map.of("InstanceId", instEcs.getInstanceId()),
                    cache,
                    Map.of("InstanceId", instEcs.getInstanceId()));

            var req = new DescribePriceRequest();
            req.setRegionId(instEcs.getRegionId());
            req.setResourceType("instance");
            req.setInstanceType(instEcs.getInstanceType());
            req.setIoOptimized(instEcs.getIoOptimized() ? "optimized" : "none");
            req.setInstanceNetworkType(instEcs.getInstanceNetworkType());
            var instEcsICT = instEcs.getInternetChargeType();
            if (instEcsICT != null && !instEcsICT.equals("")) req.setInternetChargeType(instEcsICT);
            req.setInternetMaxBandwidthOut(instEcs.getInternetMaxBandwidthOut());
            req.setImageId(instEcs.getImageId());
            req.setPriceUnit(priceUnit);
            req.setPeriod(period);

            //set disk parameters
            var dataDiskCount = 0;
            for (var entry : instEcsDisks.entrySet())
            {
                var disk = entry.getValue();
                var diskType = disk.getType(); if (diskType == null) continue;
                switch (diskType)
                {
                    case "system":
                        req.setSystemDiskCategory(disk.getCategory());
                        req.setSystemDiskSize(disk.getSize());
                    case "data":
                        dataDiskCount += 1;
                        Util.setSomething(req, "DataDisk" + dataDiskCount + "Category", disk.getCategory());
                        Util.setSomething(req, "DataDisk" + dataDiskCount + "Size", disk.getSize());
                }
            }

            var client = getAcsClient(instEcs.getRegionId(), AccKey_Readonly, AccSecret_Readonly);
            var resp = GetResponse(client, req);
            return resp.getPriceInfo().getPrice();
        }
        else if (inst instanceof DescribeDisksResponse.Disk) {
            throw new RuntimeException("Disk price check is not supported yet.");
        }
        else if (inst instanceof DescribeBandwidthPackagesResponse.BandwidthPackage) {
            throw new RuntimeException("Bandwidth price check is not supported yet.");
        }
        else throw new RuntimeException("Resource type is not supported.");
    }


    public static DescribeRenewalPriceResponse.PriceInfo.Price
    GetRenewalPrice(String region, String instanceId, String priceUnit, int period, boolean cache) throws IOException, ClientException
    {
        if (region == null || instanceId == null || priceUnit == null || period == 0)
            throw new RuntimeException("Required parameters cannot be null.");
        var req = new DescribeRenewalPriceRequest();
        req.setRegionId(region);
        req.setResourceId(instanceId);
        req.setPriceUnit(priceUnit);
        req.setPeriod(period);
        var client = getAcsClient(region, AccKey_Readonly, AccSecret_Readonly);
        var resp = GetResponse(client, req, cache);
        return resp.getPriceInfo().getPrice();
    }

    private static void setRequestParams(Map<String, ?> reqParams, RpcAcsRequest<?> req) throws NoSuchMethodException, InvocationTargetException, IllegalAccessException
    {
        //set parameters from $reqParams array
        if (reqParams != null && reqParams.size() > 0) {
            for (Map.Entry<String, ?> entry : reqParams.entrySet()) {
                Util.setSomething(req, entry.getKey(), entry.getValue());
            }
        }
    }

    private static HashMap<String, DescribeInstancesResponse.Instance>
    getFromAllPages(DefaultAcsClient client, DescribeInstancesRequest req) throws ClientException
    {
        //filler method
        BiConsumer<DescribeInstancesResponse, Map<String, DescribeInstancesResponse.Instance>> getInstInPage = (resp, result) -> {
            for (var inst : resp.getInstances()) {
                result.put(inst.getInstanceId(), inst);
            }
        };
        var resp = client.getAcsResponse(req);//get response data on first page
        var totalPages = (int)Math.ceil(resp.getTotalCount() / (double)pageSize);//calculate total page count
        var result = new HashMap<String, DescribeInstancesResponse.Instance>();
        getInstInPage.accept(resp, result);//fill result on first page
        for (var pn = 2; pn <= totalPages; pn++)//fill result on the rest of the pages
        {
            req.setPageNumber(pn);
            resp = client.getAcsResponse(req);
            getInstInPage.accept(resp, result);
        }
        return result;
    }

    private static HashMap<String, DescribeVpcsResponse.Vpc>
    getFromAllPages(DefaultAcsClient client, DescribeVpcsRequest req) throws ClientException
    {
        BiConsumer<DescribeVpcsResponse, Map<String, DescribeVpcsResponse.Vpc>> getInstInPage = (resp, result) -> {
            for (var inst : resp.getVpcs()) {
                result.put(inst.getVpcId(), inst);
            }
        };
        var resp = client.getAcsResponse(req);
        var totalPages = (int)Math.ceil(resp.getTotalCount() / (double)pageSize);
        var result = new HashMap<String, DescribeVpcsResponse.Vpc>();
        getInstInPage.accept(resp, result);
        for (var pn = 2; pn <= totalPages; pn++)
        {
            req.setPageNumber(pn);
            resp = client.getAcsResponse(req);
            getInstInPage.accept(resp, result);
        }
        return result;
    }

    private static HashMap<String, DescribeVSwitchesResponse.VSwitch>
    getFromAllPages(DefaultAcsClient client, DescribeVSwitchesRequest req) throws ClientException
    {
        BiConsumer<DescribeVSwitchesResponse, Map<String, DescribeVSwitchesResponse.VSwitch>> getInstInPage = (resp, result) -> {
            for (var inst : resp.getVSwitches()) {
                result.put(inst.getVSwitchId(), inst);
            }
        };
        var resp = client.getAcsResponse(req);
        var totalPages = (int)Math.ceil(resp.getTotalCount() / (double)pageSize);
        var result = new HashMap<String, DescribeVSwitchesResponse.VSwitch>();
        getInstInPage.accept(resp, result);
        for (var pn = 2; pn <= totalPages; pn++)
        {
            req.setPageNumber(pn);
            resp = client.getAcsResponse(req);
            getInstInPage.accept(resp, result);
        }
        return result;
    }

    private static HashMap<String, DescribeSecurityGroupsResponse.SecurityGroup>
    getFromAllPages(DefaultAcsClient client, DescribeSecurityGroupsRequest req) throws ClientException
    {
        BiConsumer<DescribeSecurityGroupsResponse, Map<String, DescribeSecurityGroupsResponse.SecurityGroup>> getInstInPage = (resp, result) -> {
            for (var inst : resp.getSecurityGroups()) {
                result.put(inst.getSecurityGroupId(), inst);
            }
        };
        var resp = client.getAcsResponse(req);
        var totalPages = (int)Math.ceil(resp.getTotalCount() / (double)pageSize);
        var result = new HashMap<String, DescribeSecurityGroupsResponse.SecurityGroup>();
        getInstInPage.accept(resp, result);
        for (var pn = 2; pn <= totalPages; pn++)
        {
            req.setPageNumber(pn);
            resp = client.getAcsResponse(req);
            getInstInPage.accept(resp, result);
        }
        return result;
    }

    private static HashMap<String, DescribeDisksResponse.Disk>
    getFromAllPages(DefaultAcsClient client, DescribeDisksRequest req) throws ClientException
    {
        BiConsumer<DescribeDisksResponse, Map<String, DescribeDisksResponse.Disk>> getInstInPage = (resp, result) -> {
            for (var inst : resp.getDisks()) {
                result.put(inst.getDiskId(), inst);
            }
        };
        var resp = client.getAcsResponse(req);
        var totalPages = (int)Math.ceil(resp.getTotalCount() / (double)pageSize);
        var result = new HashMap<String, DescribeDisksResponse.Disk>();
        getInstInPage.accept(resp, result);
        for (var pn = 2; pn <= totalPages; pn++)
        {
            req.setPageNumber(pn);
            resp = client.getAcsResponse(req);
            getInstInPage.accept(resp, result);
        }
        return result;
    }

    private static HashMap<String, DescribeRouterInterfacesResponse.RouterInterfaceType>
    getFromAllPages(DefaultAcsClient client, DescribeRouterInterfacesRequest req) throws ClientException
    {
        BiConsumer<DescribeRouterInterfacesResponse, Map<String, DescribeRouterInterfacesResponse.RouterInterfaceType>> getInstInPage = (resp, result) -> {
            for (var inst : resp.getRouterInterfaceSet()) {
                result.put(inst.getRouterInterfaceId(), inst);
            }
        };
        var resp = client.getAcsResponse(req);
        var totalPages = (int)Math.ceil(resp.getTotalCount() / (double)pageSize);
        var result = new HashMap<String, DescribeRouterInterfacesResponse.RouterInterfaceType>();
        getInstInPage.accept(resp, result);
        for (var pn = 2; pn <= totalPages; pn++)
        {
            req.setPageNumber(pn);
            resp = client.getAcsResponse(req);
            getInstInPage.accept(resp, result);
        }
        return result;
    }

    private static HashMap<String, DescribeVRoutersResponse.VRouter>
    getFromAllPages(DefaultAcsClient client, DescribeVRoutersRequest req) throws ClientException
    {
        BiConsumer<DescribeVRoutersResponse, Map<String, DescribeVRoutersResponse.VRouter>> getInstInPage = (resp, result) -> {
            for (var inst : resp.getVRouters()) {
                result.put(inst.getVRouterId(), inst);
            }
        };
        var resp = client.getAcsResponse(req);
        var totalPages = (int)Math.ceil(resp.getTotalCount() / (double)pageSize);
        var result = new HashMap<String, DescribeVRoutersResponse.VRouter>();
        getInstInPage.accept(resp, result);
        for (var pn = 2; pn <= totalPages; pn++)
        {
            req.setPageNumber(pn);
            resp = client.getAcsResponse(req);
            getInstInPage.accept(resp, result);
        }
        return result;
    }

    private static HashMap<String, DescribeDBInstancesResponse.DBInstance>
    getFromAllPages(DefaultAcsClient client, DescribeDBInstancesRequest req) throws ClientException
    {
        BiConsumer<DescribeDBInstancesResponse, Map<String, DescribeDBInstancesResponse.DBInstance>> getInstInPage = (resp, result) -> {
            for (var inst : resp.getItems()) {
                result.put(inst.getDBInstanceId(), inst);
            }
        };
        var resp = client.getAcsResponse(req);
        var totalPages = (int)Math.ceil(resp.getTotalRecordCount() / (double)pageSize);
        var result = new HashMap<String, DescribeDBInstancesResponse.DBInstance>();
        getInstInPage.accept(resp, result);
        for (var pn = 2; pn <= totalPages; pn++)
        {
            req.setPageNumber(pn);
            resp = client.getAcsResponse(req);
            getInstInPage.accept(resp, result);
        }
        return result;
    }
}
