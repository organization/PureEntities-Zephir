namespace leinne\pureentities\entity\ai\walk;

use leinne\pureentities\entity\ai\EntityAI;
use leinne\pureentities\entity\ai\navigator\EntityNavigator;
use leinne\pureentities\entity\ai\navigator\WalkEntityNavigator;
use leinne\pureentities\entity\EntityBase;
use pocketmine\block\Block;
use pocketmine\entity\Entity;
use pocketmine\item\ItemFactory;
use pocketmine\item\ItemIds;
use pocketmine\math\AxisAlignedBB;
use pocketmine\network\mcpe\protocol\LevelEventPacket;
use pocketmine\world\particle\DestroyBlockParticle;
use pocketmine\world\Position;
use pocketmine\world\sound\DoorBumpSound;
use pocketmine\world\sound\DoorCrashSound;
/**
 * This trait override most methods in the {@link EntityBase} abstract class.
 */
trait WalkEntityTrait
{
    /**
     * 문을 부수기까지의 시간을 저장합니다
     *
     * @var int
     */
    private doorBreakTime = 0;
    /**
     * 문을 부술지 판단합니다
     *
     * @var int
     */
    private doorBreakDelay = 0;
    /**
     * 가야할 블럭이 문인지 확인합니다
     *
     * @var bool
     */
    private checkDoorState = false;
    /** @var Block */
    private doorBlock = null;
    /** @var EntityNavigator */
    protected navigator = null;
    /**
     * @see EntityBase::entityBaseTick()
     *
     * @param int $tickDiff
     *
     * @return bool
     */
    protected function entityBaseTick(int tickDiff = 1) -> bool
    {
        var pos;
        var door;
        var ground;
        var diff;
        var z;
        var x;
        var goal;
        var target;
        var me;
        var hasUpdate;
        if (this->closed) {
            return false;
        }
        let hasUpdate = parent::entityBaseTick(tickDiff);
        if (!this->isMovable()) {
            return hasUpdate;
        }
        this->getNavigator()->update();
        /** @var Position $me */
        let me = this->location;
        /** @var Entity $target */
        let target = this->getTargetEntity();
        let goal = this->getNavigator()->next();
        if (goal === null) {
            return hasUpdate;
        }
        let x = goal->x - me->x;
        let z = goal->z - me->z;
        let diff = abs(x) + abs(z);
        if (!this->interactTarget() && diff != 0) {
            let hasUpdate = true;
            let ground = this->onGround ? 0.125 : 0.001;
            let this->motion->x += this->getSpeed() * ground * x / diff;
            let this->motion->z += this->getSpeed() * ground * z / diff;
        }
        let door = this->checkDoorState;
        if (!door && this->doorBreakDelay > 0) {
            let this->doorBreakTime = 0;
            let this->doorBreakDelay = 0;
        }
        let this->checkDoorState = false;
        if (hasUpdate && this->onGround) {
            /** @var EntityBase $this */
            var _;
var block;
for _, block in this->getWorld()->getCollisionBlocks(this->boundingBox->addCoord(this->motion->x, this->motion->y, this->motion->z)) {
                if (block->getCollisionBoxes()[0]->maxY - this->boundingBox->minY > 1) {
                    continue;
                }
                switch (EntityAI::checkPassablity(this->location, block)) {
                    case EntityAI::BLOCK:
                        let hasUpdate = true;
                        let this->motion->y += 0.52;
                        break;
                    case EntityAI::DOOR:
                        if (this->canBreakDoor()) {
                            let this->checkDoorState = true;
                            if (this->doorBreakTime <= 0 && ++this->doorBreakDelay > 20) {
                                let this->doorBlock = block;
                                let this->doorBreakTime = 180;
                            }
                        }
                        break;
                }
            }
        }
        if (door && !this->checkDoorState && this->doorBlock !== null) {
            let pos = this->doorBlock->getPos();
            pos->world->broadcastLevelEvent(pos, LevelEventPacket::EVENT_BLOCK_STOP_BREAK);
            let this->doorBlock = null;
        }
        this->setRotation(rad2deg(atan2(z, x)) - 90.0, target === null ? 0.0 : rad2deg(-atan2(target->location->y - me->y, sqrt((target->location->x - me->x) ** 2 + (target->location->z - me->z) ** 2))));
        return hasUpdate;
    }

    /**
     * @see EntityBase::checkBoundingBoxState()
     *
     * @param float $movX
     * @param float $movY
     * @param float $movZ
     * @param float $dx
     * @param float $dy
     * @param float $dz
     *
     * @return AxisAlignedBB
     */
    public function checkBoundingBoxState(float movX, float movY, float movZ, float &dx, float &dy, float &dz) -> <AxisAlignedBB>
    {
        var pos;
        var delay;
        var aabb;
        let aabb = parent::checkBoundingBoxState(movX, movY, movZ, dx, dy, dz);
        let delay = (int) (movX != dx) + (int) (movZ != dz);
        if (delay > 0 && this->checkDoorState) {
            let delay = -1;
            if (this->doorBlock !== null) {
                let pos = this->doorBlock->getPos();
                if (this->doorBreakTime === 180) {
                    pos->world->broadcastLevelEvent(pos, LevelEventPacket::EVENT_BLOCK_START_BREAK, 364);
                }
                if (this->doorBreakTime % mt_rand(3, 20) === 0) {
                    pos->world->addSound(pos, new DoorBumpSound());
                }
                if (--this->doorBreakTime <= 0) {
                    this->doorBlock->onBreak(ItemFactory::get(ItemIds::AIR));
                    pos->world->addSound(pos, new DoorCrashSound());
                    pos->world->addParticle(pos->add(0.5, 0.5, 0.5), new DestroyBlockParticle(this->doorBlock));
                }
            }
        }
        this->getNavigator()->addStopDelay(delay);
        return aabb;
    }

    public function getNavigator() -> <EntityNavigator>
    {
        return isset(this->navigator) ? this->navigator : (let this->navigator = new WalkEntityNavigator(this));
    }

}