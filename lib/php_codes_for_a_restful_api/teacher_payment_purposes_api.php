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
        // Create a new TeacherPaymentsPurpose
        $data = json_decode(file_get_contents('php://input'), true);
        $paymentPurpose = $data['paymentPurpose'] ?? null;
        $purposeAmount = $data['purposeAmount'] ?? null;
        $termId = $data['termId'] ?? null;

        if (!$paymentPurpose || !$purposeAmount) {
            http_response_code(400);
            echo json_encode(['message' => 'Invalid input']);
            exit;
        }

        $sql = "INSERT INTO TeacherPaymentsPurposes (paymentPurpose, purposeAmount, termId) VALUES (:paymentPurpose, :purposeAmount, :termId)";
        $stmt = $pdo->prepare($sql);
        $stmt->execute([
            ':paymentPurpose' => $paymentPurpose,
            ':purposeAmount' => $purposeAmount,
            ':termId' => $termId
        ]);

        echo json_encode(['message' => 'Teacher payment purpose created successfully']);
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

            $sql = "SELECT * FROM TeacherPaymentsPurposes WHERE id = :id";
            $stmt = $pdo->prepare($sql);
            $stmt->execute([':id' => $id]);
            $teacherPaymentPurpose = $stmt->fetch(PDO::FETCH_ASSOC);

            if ($teacherPaymentPurpose) {
                echo json_encode($teacherPaymentPurpose);
            } else {
                http_response_code(404);
                echo json_encode(['message' => 'Teacher payment purpose not found']);
            }
        } else {
            // Fetch all records
            $sql = "SELECT * FROM TeacherPaymentsPurposes";
            $stmt = $pdo->query($sql);
            $teacherPaymentPurposes = $stmt->fetchAll(PDO::FETCH_ASSOC);
            echo json_encode($teacherPaymentPurposes);
        }
        break;

    case 'PUT':
        // Update an existing TeacherPaymentsPurpose
        $data = json_decode(file_get_contents('php://input'), true);
        $id = $data['id'] ?? null;
        $paymentPurpose = $data['paymentPurpose'] ?? null;
        $purposeAmount = $data['purposeAmount'] ?? null;
        $termId = $data['termId'] ?? null;

        if (!$id || !$paymentPurpose || !$purposeAmount) {
            http_response_code(400);
            echo json_encode(['message' => 'Invalid input']);
            exit;
        }

        $sql = "UPDATE TeacherPaymentsPurposes SET paymentPurpose = :paymentPurpose, purposeAmount = :purposeAmount, termId = :termId WHERE id = :id";
        $stmt = $pdo->prepare($sql);
        $stmt->execute([
            ':id' => $id,
            ':paymentPurpose' => $paymentPurpose,
            ':purposeAmount' => $purposeAmount,
            ':termId' => $termId
        ]);

        echo json_encode(['message' => 'Teacher payment purpose updated successfully']);
        break;

    case 'DELETE':
        // Delete a specific TeacherPaymentsPurpose
        $id = $_GET['id'] ?? null;

        if (!$id) {
            http_response_code(400);
            echo json_encode(['message' => 'Invalid ID']);
            exit;
        }

        $sql = "DELETE FROM TeacherPaymentsPurposes WHERE id = :id";
        $stmt = $pdo->prepare($sql);
        $stmt->execute([':id' => $id]);

        if ($stmt->rowCount()) {
            echo json_encode(['message' => 'Teacher payment purpose deleted successfully']);
        } else {
            http_response_code(404);
            echo json_encode(['message' => 'Teacher payment purpose not found']);
        }
        break;

    default:
        http_response_code(405);
        echo json_encode(['message' => 'Method Not Allowed']);
        break;
}
?>
