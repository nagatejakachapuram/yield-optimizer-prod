// e2e/project.test.ts
var ProjectTestSuite = class {
  name = "project";
  description = "E2E tests for project-specific features";
  tests = [
    {
      name: "Project runtime environment test",
      fn: async (runtime) => {
        try {
          if (!runtime.character) {
            throw new Error("Character not loaded in runtime");
          }
          const character = runtime.character;
          if (!character.name) {
            throw new Error("Character name is missing");
          }
        } catch (error) {
          throw new Error(`Project runtime environment test failed: ${error.message}`);
        }
      }
    }
  ];
};
var project_test_default = new ProjectTestSuite();
export {
  ProjectTestSuite,
  project_test_default as default
};
//# sourceMappingURL=project.test.js.map