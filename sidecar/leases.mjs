export class Leases {
  constructor({now = Date.now, ttl = 30000} = {}) {
    this.now = now;
    this.ttl = ttl;
    this.views = new Map();
  }
  renew(userId, viewId, deviceIds) {
    this.prune();
    const key = `${userId}:${viewId}`;
    if (!this.views.has(key) && this.views.size >= 10000) throw new Error('capacity');
    const previous = new Map(deviceIds.map(id => [id, this.until(id)]));
    this.views.set(key, {userId, deviceIds: new Set(deviceIds), until: this.now() + this.ttl});
    return deviceIds.filter(id => previous.get(id) <= this.now());
  }
  release(userId, viewId) { this.views.delete(`${userId}:${viewId}`); }
  until(deviceId) {
    this.prune();
    return Math.max(0, ...Array.from(this.views.values())
      .filter(view => view.deviceIds.has(deviceId)).map(view => view.until));
  }
  prune() {
    for (const [key, view] of this.views) if (view.until <= this.now()) this.views.delete(key);
  }
}
