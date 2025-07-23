import ballerina/io;
import ballerinax/health.clients.fhir as fhir_client;
import ballerinax/health.fhir.r4;
import ballerinax/health.fhir.r4.international401;
import ballerinax/health.fhir.r4.parser;

// FHIR server config (update as needed)
fhir_client:FHIRConnectorConfig fhirServerConfig = {
    baseURL: "https://example.com",  // Example FHIR server URL
    mimeType: fhir_client:FHIR_JSON
};

final fhir_client:FHIRConnector fhirConnector = checkpanic new (fhirServerConfig, enableCapabilityStatementValidation = false);

public function main() {
    io:println("--- Ballerina FHIR Client Demo ---");

    // 1. Search for a Patient by ID
    searchPatientById("48393877");

    // 2. Conditional Create (Patient)
    conditionalCreatePatient();

    // 3. callOperation: CodeSystem $lookup (GET)
    codeSystemLookupGet();

    // 4. Transaction: Bundle with Patient and Observation
    transactionOperation();
}

function searchPatientById(string patientId) {
    io:println("\n[Search] Patient by ID: ", patientId);
    fhir_client:FHIRResponse|fhir_client:FHIRError response = fhirConnector->search("Patient", searchParameters = {"_id": patientId});
    if response is fhir_client:FHIRResponse {
        io:println("Status: ", response.httpStatusCode);
        if response.'resource == () {
            io:println("No resource found.");
            return;
        }
        r4:Bundle bundle = checkpanic parser:parse(response.'resource).ensureType();
        r4:BundleEntry[]|error entries = bundle.entry ?: error("No entries found");
        if entries is r4:BundleEntry[] {
            foreach r4:BundleEntry entry in entries {
                if entry?.'resource is json {
                    do {
                        international401:Patient patient = checkpanic parser:parse(entry?.'resource.toJson()).ensureType();
                        io:println("Patient ID: ", patient.id);
                    } on fail {
                        io:println("Failed to parse patient entry");
                    }
                }
            }
        } else {
            io:println("No valid entries found in the bundle.");
        }
    } else {
        io:println("FHIR Error (search): ", response.message());
    }
}

function conditionalCreatePatient() {
    io:println("\n[Conditional Create] Patient");
    international401:Patient patient = {
        resourceType: "Patient",
        id: "demo-123",
        text: {
            status: "generated",
            div: "<div xmlns=\"http://www.w3.org/1999/xhtml\"><table class=\"hapiPropertyTable\"><tbody/></table></div>"
        }
    };
    map<string[]> condition = {"_id": ["demo-123"]};
    fhir_client:FHIRResponse|fhir_client:FHIRError response = fhirConnector->create(patient.toJson(), onCondition = condition);
    if response is fhir_client:FHIRResponse {
        io:println("Status: ", response.httpStatusCode);
        international401:Patient createdPatient = checkpanic parser:parse(response.'resource.toJson()).ensureType();
        io:println("Created Patient ID: ", createdPatient.id);
    } else {
        io:println("FHIR Error (conditional create): ", response.message());
    }
}

function codeSystemLookupGet() {
    io:println("\n[Invoke Custom Operation] CodeSystem $lookup (GET)");
    fhir_client:FHIRResponse|fhir_client:FHIRError response = fhirConnector->callOperation(
        'type = "CodeSystem",
        operationName = "lookup",
        mode = "GET",
        queryParameters = {"code": ["2133-7"], "system": ["urn:oid:2.16.840.1.113883.6.238"]}
    );
    if response is fhir_client:FHIRResponse {
        io:println("Status: ", response.httpStatusCode);
        if response.'resource == () {
            io:println("No resource found.");
            return;
        }
        international401:Parameters parameters = checkpanic parser:parse(response.'resource).ensureType();
        io:println("Lookup Response: ", parameters.toJson());
    } else {
        io:println("FHIR Error (callOperation): ", response.message());
    }
}

function transactionOperation() {
    io:println("\n[Transaction] Bundle with Patient and Observation");

    // Create a transaction bundle
    json bundle = {
        "resourceType": "Bundle",
        "type": "transaction",
        "entry": [
            {
                "resource": {
                    "resourceType": "Patient",
                    "id": "txn-demo-patient",
                    "text": {
                        "status": "generated",
                        "div": "<div xmlns=\"http://www.w3.org/1999/xhtml\">Transaction Patient</div>"
                    }
                },
                "request": {
                    "method": "PUT",
                    "url": "Patient/txn-demo-patient"
                }
            },
            {
                "resource": {
                    "resourceType": "Observation",
                    "id": "txn-demo-obs",
                    "status": "final",
                    "code": {
                        "coding": [
                            {
                                "system": "http://loinc.org",
                                "code": "3141-9",
                                "display": "Weight Measured"
                            }
                        ]
                    },
                    "subject": {
                        "reference": "Patient/txn-demo-patient"
                    },
                    "valueQuantity": {
                        "value": 70.0,
                        "unit": "kg"
                    }
                },
                "request": {
                    "method": "PUT",
                    "url": "Observation/txn-demo-obs"
                }
            }
        ]
    };

    // Send the transaction
    fhir_client:FHIRResponse|fhir_client:FHIRError response = fhirConnector->'transaction(bundle);
    if response is fhir_client:FHIRResponse {
        io:println("Status: ", response.httpStatusCode);
        io:println("Transaction Response: ", response.'resource.toJson());
    } else {
        io:println("FHIR Error (transaction): ", response.message());
    }
}
