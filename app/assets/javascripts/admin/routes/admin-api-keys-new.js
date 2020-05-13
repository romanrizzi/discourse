import Route from "@ember/routing/route";

export default Route.extend({
  model() {
    const record = this.store.createRecord("api-key");
    record.set("scopes", []);

    return record;
  }
});
