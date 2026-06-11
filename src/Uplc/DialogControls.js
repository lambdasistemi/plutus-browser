import * as React from "react";

import FormControl from "@mui/material/FormControl";
import InputLabel from "@mui/material/InputLabel";
import MenuItem from "@mui/material/MenuItem";
import Select from "@mui/material/Select";

export const selectField = (props) => (children) => {
  const { id, label, sx, ...selectProps } = props;
  const labelId = `${id}-label`;

  return React.createElement(
    FormControl,
    { fullWidth: true, sx },
    React.createElement(InputLabel, { id: labelId }, label),
    React.createElement(
      Select,
      {
        ...selectProps,
        id,
        label,
        labelId,
      },
      ...children,
    ),
  );
};

export const menuItem = (props) => (children) =>
  React.createElement(MenuItem, props, ...children);
