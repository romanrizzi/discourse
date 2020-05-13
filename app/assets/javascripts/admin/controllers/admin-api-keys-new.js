import I18n from "I18n";
import { isBlank, isEmpty } from "@ember/utils";
import Controller from "@ember/controller";
import discourseComputed from "discourse-common/utils/decorators";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { ajax } from "discourse/lib/ajax";

export default Controller.extend({
  userModes: [
    { id: "all", name: I18n.t("admin.api.all_users") },
    { id: "single", name: I18n.t("admin.api.single_user") }
  ],
  scopesMode: [
    { id: "no_scopes", name: I18n.t("admin.api.no_scopes") },
    { id: "simple_scopes", name: I18n.t("yes_value") },
    { id: "complex_scopes", name: I18n.t("admin.api.complex_scopes") }
  ],
  useScopes: "no_scopes",
  availableScopes: null,
  scopeParams: null,

  init() {
    this._super(...arguments);
    this.set("selectedScopes", []);
    this.set("availableScopes", []);
  },

  @discourseComputed("userMode")
  showUserSelector(mode) {
    return mode === "single";
  },

  @discourseComputed("useScopes")
  showScopes(option) {
    return option !== "no_scopes";
  },

  @discourseComputed("useScopes")
  complexScopes(option) {
    return option === "complex_scopes";
  },

  @discourseComputed(
    "model.description",
    "model.username",
    "userMode",
    "useScopes",
    "model.scopes.[]"
  )
  saveDisabled(description, username, userMode, useScopes, scopes) {
    if (isBlank(description)) return true;
    if (userMode === "single" && isBlank(username)) return true;
    if (isEmpty(scopes) && useScopes !== "no_scopes") return true;
    return false;
  },

  searchEndpoints(filter) {
    if (filter === null) return [];

    const data = { q: filter };
    return ajax("/admin/api/keys/search_endpoints.json", { data }).then(
      scopes => {
        return scopes.api.map(scope => {
          return Object.assign(scope, {
            name: `${scope.path} - ${scope.action}  (${scope.method})`,
            id: `${scope.path}_${scope.method}`
          });
        });
      }
    );
  },

  actions: {
    changeUserMode(value) {
      if (value === "all") {
        this.model.set("username", null);
      }
      this.set("userMode", value);
    },

    save() {
      this.model.save().catch(popupAjaxError);
    },

    setScope(scopeID, scopeObj) {
      this.set("scopeID", scopeObj.name);
      this.set("newScope", scopeObj);
    },

    continue() {
      this.transitionToRoute("adminApiKeys.show", this.model.id);
    },

    buildScope() {
      const scopes = this.model.scopes;

      if (
        scopes.length === 0 ||
        !scopes.some(
          scope =>
            scope.path === this.newScope.path &&
            scope.method === this.newScope.method
        )
      ) {
        delete this.newScope.id;
        delete this.newScope.name;

        this.model.scopes.pushObject(this.newScope);
      }

      this.set("newScope", null);
      this.set("scopeID", null);
    },

    removeScope(scope) {
      this.model.scopes.removeObject(scope);
    }
  }
});
