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
        // Create a new Term
        $data = json_decode(file_get_contents('php://input'), true);
        $termId = $data['termId'] ?? null;
        $termName = $data['termName'] ?? null;
        $startDate = $data['startDate'] ?? null;
        $endDate = $data['endDate'] ?? null;
        $isActive = $data['isActive'] ?? null;
        $status = $data['status'] ?? null;

        if (!$termId || !$termName || !$startDate || !$isActive || !$status) {
            http_response_code(400);
            echo json_encode(['message' => 'Invalid input']);
            exit;
        }

        $sql = "INSERT INTO Terms (termId, termName, startDate, endDate, isActive, status) VALUES (:termId, :termName, :startDate, :endDate, :isActive, :status)";
        $stmt = $pdo->prepare($sql);
        $stmt->execute([
            ':termId' => $termId,
            ':termName' => $termName,
            ':startDate' => $startDate,
            ':endDate' => $endDate,
            ':isActive' => $isActive,
            ':status' => $status
        ]);

        echo json_encode(['message' => 'Term created successfully']);
        break;

    case 'GET':
        if (isset($_GET['termId'])) {
            // Fetch a specific record
            $termId = $_GET['termId'];
            if (!$termId) {
                http_response_code(400);
                echo json_encode(['message' => 'Invalid termId']);
                exit;
            }

            $sql = "SELECT * FROM Terms WHERE termId = :termId";
            $stmt = $pdo->prepare($sql);
            $stmt->execute([':termId' => $termId]);
            $term = $stmt->fetch(PDO::FETCH_ASSOC);

            if ($term) {
                echo json_encode($term);
            } else {
                http_response_code(404);
                echo json_encode(['message' => 'Term not found']);
            }
        } else {
            // Fetch all records
            $sql = "SELECT * FROM Terms";
            $stmt = $pdo->query($sql);
            $terms = $stmt->fetchAll(PDO::FETCH_ASSOC);
            echo json_encode($terms);
        }
        break;

    case 'PUT':
        // Update an existing Term
        $data = json_decode(file_get_contents('php://input'), true);
        $termId = $data['termId'] ?? null;
        $termName = $data['termName'] ?? null;
        $startDate = $data['startDate'] ?? null;
        $endDate = $data['endDate'] ?? null;
        $isActive = $data['isActive'] ?? null;
        $status = $data['status'] ?? null;

        if (!$termId || !$termName || !$startDate || !$isActive || !$status) {
            http_response_code(400);
            echo json_encode(['message' => 'Invalid input']);
            exit;
        }

        $sql = "UPDATE Terms SET termName = :termName, startDate = :startDate, endDate = :endDate, isActive = :isActive, status = :status WHERE termId = :termId";
        $stmt = $pdo->prepare($sql);
        $stmt->execute([
            ':termId' => $termId,
            ':termName' => $termName,
            ':startDate' => $startDate,
            ':endDate' => $endDate,
            ':isActive' => $isActive,
            ':status' => $status
        ]);

        echo json_encode(['message' => 'Term updated successfully']);
        break;

    case 'DELETE':
        // Delete a specific Term
        $termId = $_GET['termId'] ?? null;

        if (!$termId) {
            http_response_code(400);
            echo json_encode(['message' => 'Invalid termId']);
            exit;
        }

        $sql = "DELETE FROM Terms WHERE termId = :termId";
        $stmt = $pdo->prepare($sql);
        $stmt->execute([':termId' => $termId]);

        if ($stmt->rowCount()) {
            echo json_encode(['message' => 'Term deleted successfully']);
        } else {
            http_response_code(404);
            echo json_encode(['message' => 'Term not found']);
        }
        break;

    default:
        http_response_code(405);
        echo json_encode(['message' => 'Method Not Allowed']);
        break;
}
?>
