namespace leinne\pureentities\entity\ai\path\astar;

use leinne\pureentities\entity\ai\EntityAI;
use leinne\pureentities\entity\ai\path\PathFinder;
use pocketmine\math\Facing;
use pocketmine\math\Math;
use pocketmine\world\Position;
class AStarPathFinder extends PathFinder
{
    /** @var Node[] */
    private openNode = [];
    /** @var Node[] */
    private openHash = [];
    /** @var Node[] */
    private closeNode = [];
    /** @var array */
    private onChange = [];
    /** @var int[] */
    private yCache = [];
    /** @var int[] */
    private passablity = [];
    private findTick = -1;
    private findCount = 0;
    /**
     * 탐색을 시도할 최대 시간입니다
     *
     * @var int
     */
    protected static maximumTick = 0;
    /**
     * 1틱마다 몇개의 블럭을 탐색할지 선택합니다
     *
     * @var int
     */
    protected static blockPerTick = 0;
    public static function setData(int tick, int block) -> void
    {
        let self::$maximumTick = tick;
        let self::$blockPerTick = block;
    }

    /**
     * @param int $left
     * @param int|null $right
     */
    protected function sort(int left = 0, ?int right = null) -> void
    {
        var i;
        var j;
        var right;
        let right = isset(right) ? right : (int) (count(this->openNode) / 2);
        if (left >= right) {
            return;
        }
        let j = left;
        for (let i = j + 1; i <= right; ++i) {
            if (this->openNode[i]->getFitness() < this->openNode[left]->getFitness()) {
                ++j;
                let this->openNode[j] = this->openNode[i];
                let this->openNode[i] = this->openNode[j];
            }
        }
        let this->openNode[left] = this->openNode[j];
        let this->openNode[j] = this->openNode[left];
        this->sort(left, j - 1);
        this->sort(j + 1, right);
    }

    public function reset() -> void
    {
        let this->findTick = -1;
        let this->findCount = 0;
        let this->yCache = [];
        let this->passablity = [];
        let this->onChange = [];
        let this->openNode = [];
        let this->openHash = [];
        let this->closeNode = [];
    }

    /**
     * 최적 경로를 탐색해 결과를 도출합니다
     *
     * @return Position[]|null
     */
    public function search() -> array|null
    {
        var last;
        var change;
        var node;
        var key;
        var near;
        var p;
        var hash;
        var beforeY;
        var parent;
        var finish;
        var pos;
        var end;
        if (this->findCount >= self::$maximumTick) {
            return null;
        }
        let end = this->navigator->getGoal();
        let end->y = this->calculateYOffset(end);
        if (this->findTick === -1) {
            this->reset();
            let pos = this->navigator->getHolder()->getPosition();
            let pos->x = Math::floorFloat(pos->x) + 0.5;
            let pos->z = Math::floorFloat(pos->z) + 0.5;
            let this->openNode[] = Node::create(pos, end);
        }
        let finish = false;
        ++this->findCount;
        while (++this->findTick <= self::$blockPerTick) {
            if (empty(this->openNode)) {
                let finish = true;
                break;
            }
            this->sort();
            let parent = array_shift(this->openNode);
            unset(this->openHash[EntityAI::getHash(parent)]);
            let beforeY = parent->y;
            let parent->y = this->calculateYOffset(parent);
            let hash = EntityAI::getHash(parent);
            if (parent->y !== beforeY) {
                let p = parent->getParentNode();
                if (p !== null) {
                    parent->setGoal(p->getGoal() + p->distanceSquared(parent));
                }
                let this->onChange[hash] = true;
            }
            if (isset(this->closeNode[hash]) && this->closeNode[hash]->getGoal() <= parent->getGoal()) {
                /** 이미 최적 경로를 찾은 경우 */
                continue;
            }
            let this->closeNode[hash] = parent;
            if (parent->getFloorX() === end->getFloorX() && parent->getFloorZ() === end->getFloorZ() && parent->getFloorY() === end->getFloorY()) {
                let finish = true;
                break;
            }
            let near = this->getNear(parent);
            if (count(near) < 8) {
                let this->onChange[hash] = true;
            }
            var _;
var pos;
for _, pos in near {
                ++this->findTick;
                let key = EntityAI::getHash(pos);
                if (isset(this->closeNode[key])) {
                    /** 이미 최적 경로를 찾은 경우 */
                    continue;
                }
                let node = Node::create(pos, end, parent);
                if (isset(this->openHash[key])) {
                    /** 기존 노드보다 이동 거리가 더 길 경우 */
                    if (this->openHash[key]->getGoal() > node->getGoal()) {
                        let change = this->openHash[key];
                        change->setGoal(node->getGoal());
                        change->setParentNode(node->getParentNode());
                    }
                } else {
                    let this->openNode[] = node;
                    let this->openHash[key] = node;
                }
            }
        }
        if (finish) {
            //탐색 완료
            let last = array_pop(this->closeNode);
            let finish = [last];
            while ((let node = array_pop(this->closeNode)) !== null) {
                if (last->getParentNode()->getId() === node->getId()) {
                    let last = node;
                    if (isset(this->onChange[EntityAI::getHash(node)])) {
                        let finish[] = node;
                    }
                }
            }
            return finish;
        }
        //계속 탐색중
        let this->findTick = 0;
        return [];
    }

    /**
     * 해당 노드가 갈 수 있는 근처의 블럭좌표를 구합니다
     *
     * @param Position $pos
     *
     * @return Position[]
     */
    public function getNear(<Position> pos) -> array
    {
        var i;
        var state;
        var near;
        var diagonal;
        var facing;
        var result;
        let result = [];
        let facing = [Facing::EAST, Facing::WEST, Facing::SOUTH, Facing::NORTH];
        let diagonal = ["1:1": false, "1:-1": false, "-1:1": false, "-1:-1": false];
        var _;
var f;
for _, f in facing {
            let near = pos->getSide(f);
            let state = this->checkPassablity(near);
            if (state === EntityAI::WALL) {
                switch (f) {
                    case Facing::EAST:
                        let diagonal["1:1"] = true;
                        let diagonal["1:-1"] = true;
                        break;
                    case Facing::WEST:
                        let diagonal["-1:1"] = true;
                        let diagonal["-1:-1"] = true;
                        break;
                    case Facing::SOUTH:
                        let diagonal["1:1"] = true;
                        let diagonal["-1:1"] = true;
                        break;
                    case Facing::NORTH:
                        let diagonal["1:-1"] = true;
                        let diagonal["-1:-1"] = true;
                        break;
                }
            } else {
                if (state === EntityAI::DOOR) {
                    if (this->navigator->getHolder()->canBreakDoor()) {
                        let result[] = near;
                    }
                } elseif (near->y - this->calculateYOffset(near) <= 3) {
                    let result[] = near;
                }
            }
        }
        var index;
var isWall;
for index, isWall in diagonal {
            let i = explode(":", index);
            let near = pos->asPosition();
            let near->x += (int) i[0];
            let near->z += (int) i[1];
            let state = this->checkPassablity(near);
            if (isWall || state === EntityAI::WALL) {
                let this->passablity[EntityAI::getHash(near)] = EntityAI::WALL;
                continue;
            }
            if (state === EntityAI::DOOR) {
                if (this->navigator->getHolder()->canBreakDoor()) {
                    let result[] = near;
                }
            } elseif (near->y - this->calculateYOffset(near) <= 3) {
                let result[] = near;
            }
        }
        return result;
    }

    public function checkPassablity(<Position> pos) -> int
    {
        var hash;
        let hash = EntityAI::getHash(pos);
        if (!isset(this->mapCache[hash])) {
            let this->passablity[hash] = EntityAI::checkPassablity(pos);
        }
        return this->passablity[hash];
    }

    public function calculateYOffset(<Position> pos) -> float
    {
        var y;
        var newY;
        var hash;
        if (isset(this->yCache[let hash = EntityAI::getHash(pos)])) {
            return this->yCache[hash];
        }
        let newY = EntityAI::calculateYOffset(pos);
        let this->yCache[hash] = newY;
        for (let y = pos->getFloorY() - 1; y >= (int) newY; --y) {
            let this->yCache[Math::floorFloat(pos->x) . ":{y}:" . Math::floorFloat(pos->z)] = newY;
        }
        return newY;
    }

}