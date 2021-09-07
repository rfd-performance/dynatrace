import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.MalformedURLException;
import java.net.URL;

// Basic class that if called with "Metric_Name" and "Metric_Value" as arguments will
// make an http call to the local Dynatrace listener to store the value.

public class DynatraceMetric {

    public static void main(String[] args) {

      try {

        URL url = new URL("http://localhost:14499/metrics/ingest");
        HttpURLConnection conn = (HttpURLConnection) url.openConnection();
        conn.setRequestMethod("POST");
        conn.setRequestProperty("Content-Type", "text/plain");
        conn.setDoOutput(true);
        conn.getOutputStream().write(args[0] +" "+args[1]);
        // if (conn.getResponseCode() != 200) {
        //     throw new RuntimeException("Failed : HTTP error code : "
        //             + conn.getResponseCode());
        // }

        BufferedReader br = new BufferedReader(new InputStreamReader(
            (conn.getInputStream())));

        String output;
        System.out.println("Output from Server .... \n");
        while ((output = br.readLine()) != null) {
            System.out.println(output);
        }

        conn.disconnect();

      } catch (MalformedURLException e) {

        e.printStackTrace();

      } catch (IOException e) {

        e.printStackTrace();

      }

    }

}
