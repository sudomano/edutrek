<?php
include 'db.php';

// Set headers for CORS
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE');
header('Access-Control-Allow-Headers: Content-Type');

// Get the HTTP method
$method = $_SERVER['REQUEST_METHOD'];

switch ($method) {
    case 'POST':
        // Create a new School
        $data = json_decode(file_get_contents('php://input'), true);
        $schoolName = $data['schoolName'] ?? null;
        $schoolAddress = $data['schoolAddress'] ?? null;
        $schoolPhoneNumber = $data['schoolPhoneNumber'] ?? null;
        $schoolEmail = $data['schoolEmail'] ?? null;
        $termId = $data['termId'] ?? null;

        if (!$schoolName) {
            http_response_code(400);
            echo json_encode(['message' => 'Invalid input']);
            exit;
        }

        $sql = "INSERT INTO School (schoolName, schoolAddress, schoolPhoneNumber, schoolEmail, termId) VALUES (:schoolName, :schoolAddress, :schoolPhoneNumber, :schoolEmail, :termId)";
        $stmt = $pdo->prepare($sql);
        $stmt->execute([
            ':schoolName' => $schoolName,
            ':schoolAddress' => $schoolAddress,
            ':schoolPhoneNumber' => $schoolPhoneNumber,
            ':schoolEmail' => $schoolEmail,
            ':termId' => $termId
        ]);

        echo json_encode(['message' => 'School created successfully']);
        break;

    case 'GET':
        if (isset($_GET['id'])) {
            // Fetch a specific record
            $id = $_GET['id'];
            if (!$id) {
                http_response_code(400);
                echo json_encode(['message' => 'Invalid ID']);
                exit;
            }

            $sql = "SELECT * FROM School WHERE id = :id";
            $stmt = $pdo->prepare($sql);
            $stmt->execute([':id' => $id]);
            $school = $stmt->fetch(PDO::FETCH_ASSOC);

            if ($school) {
                echo json_encode($school);
            } else {
                http_response_code(404);
                echo json_encode(['message' => 'School not found']);
            }
        } else {
            // Fetch all records
            $sql = "SELECT * FROM School";
            $stmt = $pdo->query($sql);
            $schools = $stmt->fetchAll(PDO::FETCH_ASSOC);
            echo json_encode($schools);
        }
        break;

    case 'PUT':
        // Update an existing School
        $data = json_decode(file_get_contents('php://input'), true);
        $id = $data['id'] ?? null;
        $schoolName = $data['schoolName'] ?? null;
        $schoolAddress = $data['schoolAddress'] ?? null;
        $schoolPhoneNumber = $data['schoolPhoneNumber'] ?? null;
        $schoolEmail = $data['schoolEmail'] ?? null;
        $termId = $data['termId'] ?? null;

        if (!$id || !$schoolName) {
            http_response_code(400);
            echo json_encode(['message' => 'Invalid input']);
            exit;
        }

        $sql = "UPDATE School SET schoolName = :schoolName, schoolAddress = :schoolAddress, schoolPhoneNumber = :schoolPhoneNumber, schoolEmail = :schoolEmail, termId = :termId WHERE id = :id";
        $stmt = $pdo->prepare($sql);
        $stmt->execute([
            ':id' => $id,
            ':schoolName' => $schoolName,
            ':schoolAddress' => $schoolAddress,
            ':schoolPhoneNumber' => $schoolPhoneNumber,
            ':schoolEmail' => $schoolEmail,
            ':termId' => $termId
        ]);

        echo json_encode(['message' => 'School updated successfully']);
        break;

    case 'DELETE':
        // Delete a specific School
        $id = $_GET['id'] ?? null;

        if (!$id) {
            http_response_code(400);
            echo json_encode(['message' => 'Invalid ID']);
            exit;
        }

        $sql = "DELETE FROM School WHERE id = :id";
        $stmt = $pdo->prepare($sql);
        $stmt->execute([':id' => $id]);

        if ($stmt->rowCount()) {
            echo json_encode(['message' => 'School deleted successfully']);
        } else {
            http_response_code(404);
            echo json_encode(['message' => 'School not found']);
        }
        break;

    default:
        http_response_code(405);
        echo json_encode(['message' => 'Method Not Allowed']);
        break;
}
?>
