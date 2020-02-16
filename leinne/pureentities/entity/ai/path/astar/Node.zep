namespace leinne\pureentities\entity\ai\path\astar;

use pocketmine\world\Position;
class Node extends Position
{
    private static nextId = 0;
    /** @var int */
    private id;
    /**
     * 현재까지 이동한 거리
     * @var float
     */
    private goal = 0.0;
    /**
     * 휴리스틱 값
     * @var float
     */
    private heuristic = 0.0;
    /** @var Node|null */
    private parentNode = null;
    public static function create(<Position> pos, <Position> end, ?Node parent = null) -> <self>
    {
        var node;
        let node = new self();
        let node->id = ++Node::$nextId;
        let node->x = pos->x;
        let node->y = pos->y;
        let node->z = pos->z;
        let node->world = pos->world;
        let node->heuristic = pos->distanceSquared(end);
        if (parent !== null) {
            let node->parentNode = parent;
            let node->goal = parent->goal + pos->distanceSquared(parent);
        }
        return node;
    }

    public function getId() -> int
    {
        return this->id;
    }

    public function getGoal() -> float
    {
        return this->goal;
    }

    public function getFitness() -> float
    {
        return this->heuristic + this->goal;
    }

    public function getParentNode() -> Node|null
    {
        return this->parentNode;
    }

    public function setGoal(float score) -> void
    {
        let this->goal = score;
    }

    public function setParentNode(<Node> node) -> void
    {
        let this->parentNode = node;
    }

}