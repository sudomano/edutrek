<?php
include 'db.php';
//
// Set headers for CORS
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE');
header('Access-Control-Allow-Headers: Content-Type');

// Handle GET request
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $stmt = $pdo->query('SELECT * FROM Classes');
    $classes = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo json_encode($classes);
}

// Handle POST request
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $data = json_decode(file_get_contents('php://input'), true);
    $stmt = $pdo->prepare('INSERT INTO Classes (className, date, termId) VALUES (:className, :date, :termId)');
    $stmt->execute([
        'className' => $data['className'],
        'date' => $data['date'],
        'termId' => $data['termId']
    ]);
    echo json_encode(['status' => 'Class created']);
}

// Handle PUT request
if ($_SERVER['REQUEST_METHOD'] === 'PUT') {
    $data = json_decode(file_get_contents('php://input'), true);
    $stmt = $pdo->prepare('UPDATE Classes SET className = :className, date = :date, termId = :termId WHERE id = :id');
    $stmt->execute([
        'className' => $data['className'],
        'date' => $data['date'],
        'termId' => $data['termId'],
        'id' => $data['id']
    ]);
    echo json_encode(['status' => 'Class updated']);
}

// Handle DELETE request
if ($_SERVER['REQUEST_METHOD'] === 'DELETE') {
    parse_str(file_get_contents("php://input"), $data);
    $stmt = $pdo->prepare('DELETE FROM Classes WHERE id = :id');
    $stmt->execute(['id' => $data['id']]);
    echo json_encode(['status' => 'Class deleted']);
}
?>
