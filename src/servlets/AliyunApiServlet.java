package servlets;

import com.aliyuncs.AcsResponse;
import com.aliyuncs.ecs.model.v20140526.DescribeInstancesResponse;
import com.google.gson.Gson;
import tools.AliyunApiWrappers;
import tools.Util;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

@WebServlet(name = "AliyunApiServlet", urlPatterns = "/AliyunApiServlet")
public class AliyunApiServlet extends HttpServlet
{
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException
    {
        callMethod(request, response);
    }

    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException
    {
        callMethod(request, response);
    }

    private void callMethod(HttpServletRequest request, HttpServletResponse response) throws IOException
    {
        if (Util.AppRootDir == null || Util.AppRootDir.isEmpty())
            Util.AppRootDir = getServletConfig().getServletContext().getRealPath("/");
        String respJson = "";
        response.setCharacterEncoding("UTF-8");
        try {
            var funcName = request.getParameter("funcName");
            var args = new Gson().fromJson(request.getParameter("args"), Object[].class);

            switch (funcName) {
                case "GetInstances": {
                    String region = null; AliyunApiWrappers.RequestTypes reqType = null; Map<String, ?> reqParams = null;
                    boolean cache = true; Map<String, ?> cacheFilter = null;
                    var length = args.length;
                    if (length > 0) {
                        region = (String) args[0];
                        if (length > 1) {
                            reqType = AliyunApiWrappers.RequestTypes.valueOf(args[1].toString());
                            if (length > 2) {
                                reqParams = (Map<String, ?>) args[2];
                                if (length > 3) {
                                    cache = (boolean) args[3];
                                    if (length > 4) {
                                        cacheFilter = (Map<String, ?>) args[4];
                                    }
                                }
                            }
                        }
                    }
                    if (region == null || reqType == null) throw new RuntimeException("Region and reqType cannot be null.");

                    var result = AliyunApiWrappers.GetInstances(region, reqType, reqParams, cache, cacheFilter);
                    respJson = new Gson().toJson(Map.of("response", result));
                    break;
                }
                case "InstanceStart":
                case "InstanceStop": {
                    if (request.authenticate(response)) {
                        String region = null; String instanceId = null;
                        var length = args.length;
                        if (length > 0) {
                            region = (String) args[0];
                            if (length > 1) {
                                instanceId = (String) args[1];
                            }
                        }
                        if (region == null || instanceId == null) throw new RuntimeException("Region and instanceId cannot be null.");

                        AcsResponse result;
                        if (funcName.equals("InstanceStart"))
                            result = AliyunApiWrappers.InstanceStart(region, instanceId);
                        else
                            result = AliyunApiWrappers.InstanceStop(region, instanceId);
                        respJson = new Gson().toJson(Map.of("response", result));
                    }
                    break;
                }
                case "GetPrice": {
                    String region = null; AliyunApiWrappers.RequestTypes targetType = null; String targetId = null;
                    var length = args.length;
                    if (length > 0) {
                        region = (String) args[0];
                        if (length > 1) {
                            targetType = AliyunApiWrappers.RequestTypes.valueOf(args[1].toString());
                            if (length > 2) {
                                targetId = (String) args[2];
                            }
                        }
                    }
                    if (region == null || targetType == null || targetId == null)
                        throw new RuntimeException("Region, targetType and targetId cannot be null.");

                    var instMap = AliyunApiWrappers.GetInstances(
                            region, targetType,
                            Map.of("InstanceIds", new String[]{targetId}), true,
                            Map.of("InstanceId", targetId));
                    if (instMap.size() == 1) {
                        var inst = instMap.values().toArray()[0];
                        var price = new HashMap<String, Object>();
                        if (inst instanceof DescribeInstancesResponse.Instance) {
                            var instEcs = (DescribeInstancesResponse.Instance) inst;
                            switch (instEcs.getInstanceChargeType()) {
                                case "PostPaid":
                                    try { price.put("P-A-Y-G Hourly", AliyunApiWrappers.GetPrice(instEcs, "Hour", 1, true)); } catch (Exception ex) { }
                                    break;
                                case "PrePaid":
                                    try { price.put("Renew Monthly", AliyunApiWrappers.GetRenewalPrice(instEcs.getRegionId(), instEcs.getInstanceId(), "Month", 1, true)); } catch (Exception ex) { }
                                    try { price.put("Renew Annual", AliyunApiWrappers.GetRenewalPrice(instEcs.getRegionId(), instEcs.getInstanceId(), "Year", 1, true)); } catch (Exception ex) { }
                                    break;
                            }
                        }
                        else {
                            try { price.put("P-A-Y-G Hourly", AliyunApiWrappers.GetPrice(inst, "Hour", 1, true)); } catch (Exception ex) { }
                        }
                        respJson = new Gson().toJson(Map.of("response", price));
                    }
                    else throw new RuntimeException("No instance or more than one instances are found.");
                }
            }

            //write response
            response.getWriter().write(respJson);
        }
        catch (Exception ex) {
            respJson = new Gson().toJson(Map.of("error", ex.getMessage()));
            response.getWriter().write(respJson);
        }
    }
}
