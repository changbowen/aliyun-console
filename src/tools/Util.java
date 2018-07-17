package tools;

import com.google.gson.Gson;
import org.apache.commons.codec.digest.DigestUtils;
import java.lang.reflect.InvocationTargetException;

public class Util
{

    /**
     * IMPORTANT! AppRootDir needs to be set firstly in JSP pages or other calling blocks at least once for file loads to work.
     * For testing, set to "web". For Tomcat, consider using getServletContext().getRealPath("/").
     * End it with a forward-slash if not empty.
     */
    public static String AppRootDir;

    public static String getMD5(Object obj)
    {
        return DigestUtils.md5Hex(new Gson().toJson(obj));
    }

    public static Object getSomething(Object tgt, String getWhat) throws NoSuchMethodException, InvocationTargetException, IllegalAccessException
    {
        return tgt.getClass().getMethod("get" + getWhat).invoke(tgt);
    }

    public static void setSomething(Object tgt, String setWhat, Object val) throws NoSuchMethodException, InvocationTargetException, IllegalAccessException
    {
        tgt.getClass().getMethod("set" + setWhat, val.getClass()).invoke(tgt, val);
    }
}
