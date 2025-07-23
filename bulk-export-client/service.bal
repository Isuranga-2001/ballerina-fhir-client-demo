import ballerina/http;
import ballerinax/health.clients.fhir as fhir_client;

// Configuration for the FHIR server and bulk export settings
fhir_client:FHIRConnectorConfig fhirServerConfig = {
    baseURL: "https://bulk-data.smarthealthit.org/fhir",
    mimeType: fhir_client:FHIR_JSON,
    bulkExportConfig: bulkExportConfig // Use the FTP configuration for bulk export
};

// Configuration for bulk export
// This configuration uses FTP for file storage
fhir_client:BulkExportConfig bulkExportConfig = {
    fileServerType: fhir_client:FTP,
    fileServerUrl: "localhost",     // Change to your FTP server URL
    fileServerDirectory: "/exports" // Directory on the FTP server where files will be stored
};

// Local configuration for bulk export
// This configuration uses local file storage with a temporary file expiry time of 1 hour
// Use this configuration within 'fhirServerConfig' if you want to test locally
fhir_client:BulkExportConfig bulkExportConfigLocal = {
    fileServerType: fhir_client:LOCAL,
    tempFileExpiryTime: 3600 // 1 hour
};

// Create a FHIR connector instance with the specified configuration
// Disabling capability statement validation for simplicity
final fhir_client:FHIRConnector fhirConnector = check new (fhirServerConfig, enableCapabilityStatementValidation = false);

// Export record type to hold export details
type Export record {
    string exportId;
    string pollingUrl;
};

// Demonstration service for handling FHIR Patient bulk export requests
// The service listens on port 8080 and provides endpoints for export and status checking
service /Patient on new http:Listener(8080) {
    isolated resource function get export(http:Request req) returns http:Response|error? {
        // Initiate a bulk export for Patient resources
        // The response will contain the export ID and polling URL for checking status
        fhir_client:FHIRResponse response = check fhirConnector->bulkExport(fhir_client:EXPORT_PATIENT);

        // Convert the response to JSON and extract export details
        json responseBody = response.'resource.toJson();
        Export exportResult = {
            exportId: check responseBody.exportId,
            pollingUrl: check responseBody.pollingUrl
        };

        // Create an HTTP response with the export details
        // Set the X-Progress header to indicate the status of the export
        http:Response httpResponse = new;
        httpResponse.setJsonPayload(exportResult.toJson());
        httpResponse.setHeader("X-Progress", response.serverResponseHeaders["X-Progress"] ?: "In-progress");
        httpResponse.statusCode = response.httpStatusCode;
        return httpResponse;
    }

    isolated resource function get [string exportId]/status() returns http:Response|error? {
        // Check the status of a specific export using the export ID
        // The response will contain the current status of the export
        fhir_client:FHIRResponse response = check fhirConnector->bulkStatus(exportId = exportId);

        // Create an HTTP response with the export status details
        // Set the X-Progress header to indicate the status of the export
        http:Response httpResponse = new;
        httpResponse.setJsonPayload(response.'resource.toJson());
        httpResponse.setHeader("X-Progress", response.serverResponseHeaders["X-Progress"] ?: "In-progress");
        httpResponse.statusCode = response.httpStatusCode;
        return httpResponse;
    }
}
